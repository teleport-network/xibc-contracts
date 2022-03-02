// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../libraries/packet/Packet.sol";
import "../libraries/app/Transfer.sol";
import "../libraries/utils/Bytes.sol";
import "../libraries/utils/Strings.sol";
import "../interfaces/IPacket.sol";
import "../interfaces/IClientManager.sol";
import "../interfaces/ITransfer.sol";
import "../interfaces/IERC20XIBC.sol";
import "../interfaces/IAccessManager.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract MockTransfer is Initializable, ITransfer, OwnableUpgradeable ,ReentrancyGuardUpgradeable{
    using Strings for *;
    using Bytes for *;

    bytes32 public constant BIND_TOKEN_ROLE = keccak256("BIND_TOKEN_ROLE");
    bytes32 public constant MULTISEND_ROLE = keccak256("MULTISEND_ROLE");

    string private constant PORT = "FT";

    IPacket public packet;
    IClientManager public clientManager;
    IAccessManager public accessManager;

    // token come in
    address[] public override boundTokens;
    mapping(address => TransferDataTypes.InToken) public bindings; // mapping(token => InToken)
    mapping(string => address) public override bindingTraces; // mapping(origin_chain/origin_token => token)

    // token out
    mapping(address => mapping(string => uint256)) public override outTokens; // mapping(token, mapping(dst_chain => amount))
    // use address(0) as base token address

    TransferDataTypes.TransferPacketData public latestPacket;

    uint256 public version;

    function setVersion(uint256 _version) public {
        version = _version;
    }

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
        address tokenAddress,
        string calldata oriToken,
        string calldata oriChain
    ) external onlyAuthorizee(BIND_TOKEN_ROLE) {
        require(tokenAddress != address(0), "invalid ERC20 address");
        string memory sourceChain = clientManager.getChainName();
        require(
            !sourceChain.equals(oriChain),
            "sourceChain can't equal to destChain"
        );
        
        if (bindings[tokenAddress].bound) {
            // rebind
            string memory reBindKey = Strings.strConcat(
                Strings.strConcat(bindings[tokenAddress].oriChain, "/"),
                bindings[tokenAddress].oriToken
            );
            delete bindingTraces[reBindKey];
        } else {
            boundTokens.push(tokenAddress);
        }

        string memory key = Strings.strConcat(
            Strings.strConcat(oriChain, "/"),
            oriToken
        );

        bindings[tokenAddress] = TransferDataTypes.InToken({
            oriChain: oriChain,
            oriToken: oriToken,
            amount: 0,
            bound: true
        });
        bindingTraces[key] = tokenAddress;
    }

    function sendTransferERC20(
        TransferDataTypes.ERC20TransferData calldata transferData
    ) external override nonReentrant{
        string memory sourceChain = clientManager.getChainName();
        require(
            !sourceChain.equals(transferData.destChain),
            "sourceChain can't equal to destChain"
        );

        string memory oriToken;

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

            oriToken = bindings[transferData.tokenAddress].oriToken;
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

            oriToken = "";
        }
        // send packet
        string[] memory ports = new string[](1);
        bytes[] memory dataList = new bytes[](1);
        ports[0] = PORT;

        dataList[0] = abi.encode(
            TransferDataTypes.TransferPacketData({
                srcChain: sourceChain,
                destChain: transferData.destChain,
                sender: msg.sender.addressToString(),
                receiver: transferData.receiver,
                amount: transferData.amount.toBytes(),
                token: transferData.tokenAddress.addressToString(),
                oriToken: oriToken
            })
        );

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
    ) external override nonReentrant onlyAuthorizee(MULTISEND_ROLE) returns (bytes memory) {
        string memory sourceChain = clientManager.getChainName();
        require(
            !sourceChain.equals(transferData.destChain),
            "sourceChain can't equal to destChain"
        );

        string memory oriToken;

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
            oriToken = bindings[transferData.tokenAddress].oriToken;
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
            oriToken = "";
        }

        return
            abi.encode(
                TransferDataTypes.TransferPacketData({
                    srcChain: sourceChain,
                    destChain: transferData.destChain,
                    sender: transferData.sender.addressToString(),
                    receiver: transferData.receiver,
                    amount: transferData.amount.toBytes(),
                    token: transferData.tokenAddress.addressToString(),
                    oriToken: oriToken
                })
            );
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
        // send packet
        string[] memory ports = new string[](1);
        bytes[] memory dataList = new bytes[](1);
        ports[0] = PORT;
        dataList[0] = abi.encode(
            TransferDataTypes.TransferPacketData({
                srcChain: sourceChain,
                destChain: transferData.destChain,
                sender: msg.sender.addressToString(),
                receiver: transferData.receiver,
                amount: msg.value.toBytes(),
                token: address(0).addressToString(),
                oriToken: ""
            })
        );
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

        return
            abi.encode(
                TransferDataTypes.TransferPacketData({
                    srcChain: sourceChain,
                    destChain: transferData.destChain,
                    sender: transferData.sender.addressToString(),
                    receiver: transferData.receiver,
                    amount: msg.value.toBytes(),
                    token: address(0).addressToString(),
                    oriToken: ""
                })
            );
    }

    function onRecvPacket(bytes calldata data)
        external
        override
        nonReentrant
        returns (PacketTypes.Result memory)
    {
        TransferDataTypes.TransferPacketData memory packetData = abi.decode(
            data,
            (TransferDataTypes.TransferPacketData)
        );

        latestPacket = packetData;
        if (bytes(packetData.oriToken).length == 0) {
            // token come in
            address tokenAddress = bindingTraces[
                Strings.strConcat(
                    Strings.strConcat(packetData.srcChain, "/"),
                    packetData.token
                )
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
            (bool success, ) = packetData.receiver.parseAddr().call{value: packetData.amount.toUint256()}("");
            if (!success ) {
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
        nonReentrant
        onlyPacket
    {
        if (!Bytes.equals(result, hex"01")) {
            _refundTokens(
                abi.decode(data, (TransferDataTypes.TransferPacketData))
            );
        }
    }

    function _refundTokens(TransferDataTypes.TransferPacketData memory data)
        private
    {
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
                "unlock ERC20 token to sender failed"
            );
            outTokens[data.token.parseAddr()][data.destChain] -= data
                .amount
                .toUint256();
        } else {
            // refund base token
            (bool success, ) = data.sender.parseAddr().call{
                value: data.amount.toUint256()
            }("");
            require(success, "unlock base token to sender failed");
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
    function NewAcknowledgement(bool success, string memory errMsg)
        public
        pure
        returns (bytes memory)
    {
        bytes[] memory results = new bytes[](1);
        results[0] = hex"01";

        PacketTypes.Acknowledgement memory data;
        if (success) {
            data.results = results;
        } else {
            data.message = errMsg;
        }
        return
            abi.encode(
                PacketTypes.Acknowledgement({
                    results: data.results,
                    message: data.message
                })
            );
    }

    function NewAcknowledgementTest(
        bytes[] memory results,
        string memory message
    ) public pure returns (bytes memory) {
        PacketTypes.Acknowledgement memory data;
        data.results = results;
        data.message = message;

        return
            abi.encode(
                PacketTypes.Acknowledgement({
                    results: data.results,
                    message: data.message
                })
            );
    }

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

    // ===========================================================================

    function getLatestPacket()
        external
        view
        override
        returns (TransferDataTypes.TransferPacketData memory)
    {
        return latestPacket;
    }

    function getBindings(address token)
        external
        view
        override
        returns (TransferDataTypes.InToken memory)
    {
        return bindings[token];
    }
}
