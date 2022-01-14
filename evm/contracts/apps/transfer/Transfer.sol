// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../../proto/TokenTransfer.sol";
import "../../proto/Ack.sol";
import "../../core/client/ClientManager.sol";
import "../../libraries/packet/Packet.sol";
import "../../libraries/app/Transfer.sol";
import "../../libraries/utils/Bytes.sol";
import "../../libraries/utils/Strings.sol";
import "../../interfaces/IPacket.sol";
import "../../interfaces/ITransfer.sol";
import "../../interfaces/IERC20XIBC.sol";
import "../../interfaces/IAccessManager.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Transfer is Initializable, ITransfer, OwnableUpgradeable {
    using Strings for *;
    using Bytes for *;

    bytes32 public constant BIND_TOKEN_ROLE = keccak256("BIND_TOKEN_ROLE");

    string private constant PORT = "FT";

    IPacket public packet;
    IClientManager public clientManager;
    IAccessManager public accessManager;

    // Token come in
    address[] public boundTokens;
    mapping(address => TransferDataTypes.InToken) public bindings; // mapping(token => InToken)
    mapping(string => address) public bindingTraces; // mapping(origin_chain/origin_token => token)

    // Token out
    mapping(address => mapping(string => uint256)) public outTokens; // mapping(token, mapping(dst_chain => amount))
    // use address(0) as base token address

    bytes32 public constant MULTISEND_ROLE = keccak256("MULTISEND_ROLE");

    TokenTransfer.Data public latestPacket;

    modifier onlyPacket() {
        require(msg.sender == address(packet), "caller not packet contract");
        _;
    }

    // only authorized accounts can perform related transactions
    modifier onlyAuthorizee(bytes32 role) {
        require(accessManager.hasRole(role, _msgSender()), "not authorized");
        _;
    }

    function initialize(
        address packetContract,
        address clientManagerContract,
        address accessManagerContract
    ) public initializer {
        packet = IPacket(packetContract);
        clientManager = IClientManager(clientManagerContract);
        accessManager = IAccessManager(accessManagerContract);
    }

    function bindToken(
        address tokenAddres,
        string calldata oriToken,
        string calldata oriChain
    ) external onlyAuthorizee(BIND_TOKEN_ROLE) {
        require(
            !bindings[tokenAddres].bound,
            "source chain should not be bound before"
        );

        boundTokens.push(tokenAddres);
        bindings[tokenAddres] = TransferDataTypes.InToken({
            oriChain: oriChain,
            oriToken: oriToken,
            amount: 0,
            bound: true
        });
        bindingTraces[
            oriChain.toSlice().concat("/".toSlice()).toSlice().concat(
                oriToken.toSlice()
            )
        ] = tokenAddres;
    }

    function sendTransferERC20(
        TransferDataTypes.ERC20TransferData calldata transferData
    ) external override {
        string memory sourceChain = clientManager.getChainName();
        require(
            !sourceChain.equals(transferData.destChain),
            "sourceChain can't equal to destChain"
        );

        TokenTransfer.Data memory packetData;

        // if is crossed chain token
        if (bindings[transferData.tokenAddress].bound) {
            // back to origin
            require(
                bindings[transferData.tokenAddress].amount >=
                    transferData.amount,
                "insufficient liquidity"
            );

            require(
                _burn(
                    transferData.tokenAddress,
                    msg.sender,
                    transferData.amount
                ),
                "burn token failed"
            );

            bindings[transferData.tokenAddress].amount -= transferData.amount;

            packetData = TokenTransfer.Data({
                srcChain: sourceChain,
                destChain: transferData.destChain,
                sender: msg.sender.addressToString(),
                receiver: transferData.receiver,
                amount: transferData.amount.toBytes(),
                token: transferData.tokenAddress.addressToString(),
                oriToken: bindings[transferData.tokenAddress].oriToken
            });
        } else {
            // outgoing
            require(
                transferData.tokenAddress != address(0),
                "can't be zero address"
            );

            require(
                IERC20(transferData.tokenAddress).transferFrom(
                    msg.sender,
                    address(this),
                    transferData.amount
                ),
                "lock failed, unsufficient allowance"
            );

            outTokens[transferData.tokenAddress][
                transferData.destChain
            ] += transferData.amount;

            packetData = TokenTransfer.Data({
                srcChain: sourceChain,
                destChain: transferData.destChain,
                sender: msg.sender.addressToString(),
                receiver: transferData.receiver,
                amount: transferData.amount.toBytes(),
                token: transferData.tokenAddress.addressToString(),
                oriToken: ""
            });
        }

        // send packet
        string[] memory ports = new string[](1);
        bytes[] memory dataList = new bytes[](1);
        ports[0] = PORT;
        dataList[0] = TokenTransfer.encode(packetData);
        PacketTypes.Packet memory crossPacket = PacketTypes.Packet({
            sequence: packet.getNextSequenceSend(
                sourceChain,
                transferData.destChain
            ),
            sourceChain: sourceChain,
            destChain: transferData.destChain,
            relayChain: transferData.relayChain,
            ports: ports,
            dataList: dataList
        });
        packet.sendPacket(crossPacket);
    }

    function transferERC20(
        TransferDataTypes.ERC20TransferDataMulti calldata transferData
    ) external override onlyAuthorizee(MULTISEND_ROLE) returns (bytes memory) {
        string memory sourceChain = clientManager.getChainName();
        require(
            !sourceChain.equals(transferData.destChain),
            "sourceChain can't equal to destChain"
        );

        TokenTransfer.Data memory packetData;

        // if is crossed chain token
        if (bindings[transferData.tokenAddress].bound) {
            // back to origin
            require(
                bindings[transferData.tokenAddress].amount >=
                    transferData.amount,
                "insufficient liquidity"
            );

            require(
                _burn(
                    transferData.tokenAddress,
                    transferData.sender,
                    transferData.amount
                ),
                "burn token failed"
            );

            bindings[transferData.tokenAddress].amount -= transferData.amount;

            packetData = TokenTransfer.Data({
                srcChain: sourceChain,
                destChain: transferData.destChain,
                sender: transferData.sender.addressToString(),
                receiver: transferData.receiver,
                amount: transferData.amount.toBytes(),
                token: transferData.tokenAddress.addressToString(),
                oriToken: bindings[transferData.tokenAddress].oriToken
            });
        } else {
            // outgoing
            require(
                transferData.tokenAddress != address(0),
                "can't be zero address"
            );

            require(
                IERC20(transferData.tokenAddress).transferFrom(
                    transferData.sender,
                    address(this),
                    transferData.amount
                ),
                "lock failed, unsufficient allowance"
            );

            outTokens[transferData.tokenAddress][
                transferData.destChain
            ] += transferData.amount;

            packetData = TokenTransfer.Data({
                srcChain: sourceChain,
                destChain: transferData.destChain,
                sender: transferData.sender.addressToString(),
                receiver: transferData.receiver,
                amount: transferData.amount.toBytes(),
                token: transferData.tokenAddress.addressToString(),
                oriToken: ""
            });
        }

        return TokenTransfer.encode(packetData);
    }

    function sendTransferBase(
        TransferDataTypes.BaseTransferData calldata transferData
    ) external payable override {
        string memory sourceChain = clientManager.getChainName();
        require(
            !sourceChain.equals(transferData.destChain),
            "sourceChain can't be equal to destChain"
        );

        require(msg.value > 0, "value must be greater than 0");

        outTokens[address(0)][transferData.destChain] += msg.value;

        TokenTransfer.Data memory packetData = TokenTransfer.Data({
            srcChain: sourceChain,
            destChain: transferData.destChain,
            sender: msg.sender.addressToString(),
            receiver: transferData.receiver,
            amount: msg.value.toBytes(),
            token: address(0).addressToString(),
            oriToken: ""
        });

        // send packet
        string[] memory ports = new string[](1);
        bytes[] memory dataList = new bytes[](1);
        ports[0] = PORT;
        dataList[0] = TokenTransfer.encode(packetData);
        PacketTypes.Packet memory crossPacket = PacketTypes.Packet({
            sequence: packet.getNextSequenceSend(
                sourceChain,
                transferData.destChain
            ),
            sourceChain: sourceChain,
            destChain: transferData.destChain,
            relayChain: transferData.relayChain,
            ports: ports,
            dataList: dataList
        });
        packet.sendPacket(crossPacket);
    }

    function transferBase(
        TransferDataTypes.BaseTransferDataMulti calldata transferData
    )
        external
        payable
        override
        onlyAuthorizee(MULTISEND_ROLE)
        returns (bytes memory)
    {
        string memory sourceChain = clientManager.getChainName();
        require(
            !sourceChain.equals(transferData.destChain),
            "sourceChain can't be equal to destChain"
        );

        require(msg.value > 0, "value must be greater than 0");

        outTokens[address(0)][transferData.destChain] += msg.value;

        TokenTransfer.Data memory packetData = TokenTransfer.Data({
            srcChain: sourceChain,
            destChain: transferData.destChain,
            sender: transferData.sender.addressToString(),
            receiver: transferData.receiver,
            amount: msg.value.toBytes(),
            token: address(0).addressToString(),
            oriToken: ""
        });

        return TokenTransfer.encode(packetData);
    }

    function onRecvPacket(bytes calldata data)
        external
        override
        onlyPacket
        returns (PacketTypes.Result memory)
    {
        TokenTransfer.Data memory packetData = TokenTransfer.decode(data);

        latestPacket = packetData;

        if (bytes(packetData.oriToken).length == 0) {
            // token come in
            address tokenAddress = bindingTraces[
                packetData
                    .srcChain
                    .toSlice()
                    .concat("/".toSlice())
                    .toSlice()
                    .concat(packetData.token.toSlice())
            ];

            // check bindings
            if (!bindings[tokenAddress].bound) {
                return
                    _newAcknowledgement(
                        false,
                        "onRecvPackt: binding is not exist"
                    );
            }

            if (
                !_mint(
                    tokenAddress,
                    packetData.receiver.parseAddr(),
                    packetData.amount.toUint256()
                )
            ) {
                return _newAcknowledgement(false, "onRecvPackt: mint failed");
            }

            bindings[tokenAddress].amount += packetData.amount.toUint256();
        } else if (packetData.oriToken.parseAddr() != address(0)) {
            // ERC20 token back to origin
            if (
                packetData.amount.toUint256() >
                outTokens[packetData.oriToken.parseAddr()][packetData.srcChain]
            ) {
                return
                    _newAcknowledgement(
                        false,
                        "onRecvPackt: amount could not be greater than locked amount"
                    );
            }

            if (
                !IERC20(packetData.oriToken.parseAddr()).transfer(
                    packetData.receiver.parseAddr(),
                    packetData.amount.toUint256()
                )
            ) {
                return
                    _newAcknowledgement(
                        false,
                        "onRecvPackt: unlock to receiver failed"
                    );
            }

            outTokens[packetData.oriToken.parseAddr()][
                packetData.srcChain
            ] -= packetData.amount.toUint256();
        } else {
            // Base token back to origin
            if (
                packetData.amount.toUint256() >
                outTokens[address(0)][packetData.srcChain]
            ) {
                return
                    _newAcknowledgement(
                        false,
                        "onRecvPackt: amount could not be greater than locked amount"
                    );
            }

            if (
                !payable(packetData.receiver.parseAddr()).send(
                    packetData.amount.toUint256()
                )
            ) {
                return
                    _newAcknowledgement(
                        false,
                        "onRecvPackt: unlock to receiver failed"
                    );
            }

            outTokens[address(0)][packetData.srcChain] -= packetData
                .amount
                .toUint256();
        }

        return _newAcknowledgement(true, "");
    }

    function onAcknowledgementPacket(bytes calldata data, bytes calldata result)
        external
        override
        onlyPacket
    {
        if (!Bytes.equals(result, hex"01")) {
            _refundTokens(TokenTransfer.decode(data));
        }
    }

    function _refundTokens(TokenTransfer.Data memory data) private {
        if (bytes(data.oriToken).length > 0) {
            // refund crossed chain token
            require(
                _mint(
                    data.token.parseAddr(),
                    data.sender.parseAddr(),
                    data.amount.toUint256()
                ),
                "mint back to sender failed"
            );
            bindings[data.token.parseAddr()].amount += data.amount.toUint256();
        } else if (data.token.parseAddr() != address(0)) {
            // refund native ERC20 token
            require(
                IERC20(data.token.parseAddr()).transfer(
                    data.sender.parseAddr(),
                    data.amount.toUint256()
                ),
                "unlock to sender failed"
            );
            outTokens[data.token.parseAddr()][data.destChain] -= data
                .amount
                .toUint256();
        } else {
            // refund base token
            require(
                payable(data.sender.parseAddr()).send(data.amount.toUint256()),
                "unlock to sender failed"
            );
            outTokens[address(0)][data.destChain] -= data.amount.toUint256();
        }
    }

    function _newAcknowledgement(bool success, string memory errMsg)
        private
        pure
        returns (PacketTypes.Result memory)
    {
        PacketTypes.Result memory result;
        if (success) {
            result.result = hex"01";
        } else {
            result.message = errMsg;
        }
        return result;
    }

    // ===========================================================================

    function _burn(
        address destContract,
        address account,
        uint256 amount
    ) private returns (bool) {
        try IERC20XIBC(destContract).burnFrom(account, amount) {
            return true;
        } catch (bytes memory) {
            return false;
        }
    }

    function _mint(
        address destContract,
        address to,
        uint256 amount
    ) private returns (bool) {
        try IERC20XIBC(destContract).mint(to, amount) {
            return true;
        } catch (bytes memory) {
            return false;
        }
    }
}