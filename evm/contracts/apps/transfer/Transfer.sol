// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../../libraries/packet/Packet.sol";
import "../../libraries/app/Transfer.sol";
import "../../libraries/utils/Bytes.sol";
import "../../libraries/utils/Strings.sol";
import "../../interfaces/IClientManager.sol";
import "../../interfaces/IPacket.sol";
import "../../interfaces/ITransfer.sol";
import "../../interfaces/IERC20XIBC.sol";
import "../../interfaces/IAccessManager.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract Transfer is
    Initializable,
    ITransfer,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
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

    // time based supply limit
    mapping(address => TransferDataTypes.TimeBasedSupplyLimit) public limits; // mapping(token => TimeBasedSupplyLimit)

    TransferDataTypes.TransferPacketData public latestPacket;

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

    /**
     * @notice bind token
     * @param tokenAddress token address
     * @param oriToken origin token address
     * @param oriChain origin chain
     */
    function bindToken(
        address tokenAddress,
        string calldata oriToken,
        string calldata oriChain
    ) external onlyAuthorizee(BIND_TOKEN_ROLE) {
        require(tokenAddress != address(0), "invalid ERC20 address");

        string memory sourceChain = clientManager.getChainName();
        require(
            !sourceChain.equals(oriChain),
            "sourceChain can't equal to oriChain"
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

    /**
     * @notice enable time based supply limit
     * @param tokenAddress token address
     * @param timePeriod calculation time period
     * @param timeBasedLimit time based limit
     * @param maxAmount max amount single transfer
     * @param minAmount min amount single transfer
     */
    function enableTimeBasedSupplyLimit(
        address tokenAddress,
        uint256 timePeriod,
        uint256 timeBasedLimit,
        uint256 maxAmount,
        uint256 minAmount
    ) external onlyAuthorizee(BIND_TOKEN_ROLE) {
        require(!limits[tokenAddress].enable, "already enable");
        require(
            timePeriod > 0 &&
                minAmount > 0 &&
                maxAmount > minAmount &&
                timeBasedLimit > maxAmount,
            "invalid limit"
        );

        limits[tokenAddress] = TransferDataTypes.TimeBasedSupplyLimit({
            enable: true,
            timePeriod: timePeriod,
            timeBasedLimit: timeBasedLimit,
            maxAmount: maxAmount,
            minAmount: minAmount,
            previousTime: block.timestamp,
            currentSupply: 0
        });
    }

    /**
     * @notice disable time based supply limit
     * @param tokenAddress token address
     */
    function disableTimeBasedSupplyLimit(address tokenAddress)
        external
        onlyAuthorizee(BIND_TOKEN_ROLE)
    {
        require(limits[tokenAddress].enable, "not enable");
        delete limits[tokenAddress];
    }

    function sendTransfer(
        TransferDataTypes.TransferData memory transferData,
        PacketTypes.Fee memory fee
    ) public payable override nonReentrant {
        string memory sourceChain = clientManager.getChainName();
        require(
            !sourceChain.equals(transferData.destChain),
            "sourceChain can't equal to destChain"
        );

        uint64 sequence = packet.getNextSequenceSend(
            sourceChain,
            transferData.destChain
        );

        string[] memory ports = new string[](1);
        bytes[] memory dataList = new bytes[](1);
        ports[0] = PORT;

        if (transferData.tokenAddress == address(0)) {
            // transfer base token

            outTokens[address(0)][transferData.destChain] += transferData
                .amount;

            // send packet
            dataList[0] = abi.encode(
                TransferDataTypes.TransferPacketData({
                    srcChain: sourceChain,
                    destChain: transferData.destChain,
                    sequence: sequence,
                    sender: msg.sender.addressToString(),
                    receiver: transferData.receiver,
                    amount: transferData.amount.toBytes(),
                    token: address(0).addressToString(),
                    oriToken: ""
                })
            );
            PacketTypes.Packet memory crossPacket = PacketTypes.Packet({
                sequence: sequence,
                sourceChain: sourceChain,
                destChain: transferData.destChain,
                relayChain: transferData.relayChain,
                ports: ports,
                dataList: dataList
            });

            if (fee.tokenAddress == address(0)) {
                require(
                    transferData.amount > 0 &&
                        msg.value == transferData.amount + fee.amount,
                    "invalid value"
                );
                packet.sendPacket{value: fee.amount}(crossPacket, fee);
            } else {
                require(
                    transferData.amount > 0 && msg.value == transferData.amount,
                    "invalid value"
                );
                // send fee to packet
                require(
                    IERC20(fee.tokenAddress).transferFrom(
                        msg.sender,
                        address(packet),
                        fee.amount
                    ),
                    "lock failed, unsufficient allowance"
                );
                packet.sendPacket(crossPacket, fee);
            }
        } else {
            // transfer ERC20 token

            string memory oriToken;
            // if is crossed chain token
            if (bindings[transferData.tokenAddress].bound) {
                // back to origin
                require(
                    Strings.equals(
                        transferData.destChain,
                        bindings[transferData.tokenAddress].oriChain
                    ),
                    "destChain does not match the bound one"
                );

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

                bindings[transferData.tokenAddress].amount -= transferData
                    .amount;

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
            dataList[0] = abi.encode(
                TransferDataTypes.TransferPacketData({
                    srcChain: sourceChain,
                    destChain: transferData.destChain,
                    sequence: sequence,
                    sender: msg.sender.addressToString(),
                    receiver: transferData.receiver,
                    amount: transferData.amount.toBytes(),
                    token: transferData.tokenAddress.addressToString(),
                    oriToken: oriToken
                })
            );

            PacketTypes.Packet memory crossPacket = PacketTypes.Packet({
                sequence: sequence,
                sourceChain: sourceChain,
                destChain: transferData.destChain,
                relayChain: transferData.relayChain,
                ports: ports,
                dataList: dataList
            });

            if (fee.tokenAddress == address(0)) {
                require(msg.value == fee.amount, "invalid value");
                packet.sendPacket{value: fee.amount}(crossPacket, fee);
            } else {
                require(msg.value == 0, "invalid value");
                // send fee to packet
                require(
                    IERC20(fee.tokenAddress).transferFrom(
                        msg.sender,
                        address(packet),
                        fee.amount
                    ),
                    "lock failed, unsufficient allowance"
                );
                packet.sendPacket(crossPacket, fee);
            }
        }
    }

    function transfer(TransferDataTypes.TransferDataMulti calldata transferData)
        external
        payable
        override
        onlyAuthorizee(MULTISEND_ROLE)
        nonReentrant
        returns (bytes memory)
    {
        string memory sourceChain = clientManager.getChainName();
        require(
            !sourceChain.equals(transferData.destChain),
            "sourceChain can't equal to destChain"
        );

        uint64 sequence = packet.getNextSequenceSend(
            sourceChain,
            transferData.destChain
        );

        if (transferData.tokenAddress == address(0)) {
            // transfer base token

            require(transferData.amount == msg.value, "invalid value");
            outTokens[address(0)][transferData.destChain] += transferData
                .amount;

            return
                abi.encode(
                    TransferDataTypes.TransferPacketData({
                        srcChain: sourceChain,
                        destChain: transferData.destChain,
                        sequence: sequence,
                        sender: transferData.sender.addressToString(),
                        receiver: transferData.receiver,
                        amount: transferData.amount.toBytes(),
                        token: address(0).addressToString(),
                        oriToken: ""
                    })
                );
        } else {
            // transfer ERC20 token

            require(msg.value == 0, "invalid value");

            string memory oriToken;
            // if is crossed chain token
            if (bindings[transferData.tokenAddress].bound) {
                // back to origin
                require(
                    Strings.equals(
                        transferData.destChain,
                        bindings[transferData.tokenAddress].oriChain
                    ),
                    "destChain does not match the bound one"
                );
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

                bindings[transferData.tokenAddress].amount -= transferData
                    .amount;

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
                        sequence: sequence,
                        sender: transferData.sender.addressToString(),
                        receiver: transferData.receiver,
                        amount: transferData.amount.toBytes(),
                        token: transferData.tokenAddress.addressToString(),
                        oriToken: oriToken
                    })
                );
        }
    }

    function onRecvPacket(bytes calldata data)
        external
        override
        nonReentrant
        onlyPacket
        returns (PacketTypes.Result memory)
    {
        TransferDataTypes.TransferPacketData memory packetData = abi.decode(
            data,
            (TransferDataTypes.TransferPacketData)
        );
        latestPacket = packetData;

        address tokenAddress;
        address receiver = packetData.receiver.parseAddr();
        uint256 amount = packetData.amount.toUint256();

        if (bytes(packetData.oriToken).length == 0) {
            // token come in
            tokenAddress = bindingTraces[
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

            if (updateTimeBasedLimtSupply(tokenAddress, amount)) {
                return
                    _newAcknowledgement(false, "onRecvPackt: invalid amount");
            }

            if (!_mint(tokenAddress, receiver, amount)) {
                return _newAcknowledgement(false, "onRecvPackt: mint failed");
            }

            bindings[tokenAddress].amount += amount;

            return _newAcknowledgement(true, "");
        }

        tokenAddress = packetData.oriToken.parseAddr();
        if (tokenAddress != address(0)) {
            // ERC20 token back to origin
            if (amount > outTokens[tokenAddress][packetData.srcChain]) {
                return
                    _newAcknowledgement(
                        false,
                        "onRecvPackt: amount could not be greater than locked amount"
                    );
            }

            if (updateTimeBasedLimtSupply(tokenAddress, amount)) {
                return
                    _newAcknowledgement(false, "onRecvPackt: invalid amount");
            }

            if (!IERC20(tokenAddress).transfer(receiver, amount)) {
                return
                    _newAcknowledgement(
                        false,
                        "onRecvPackt: unlock to receiver failed"
                    );
            }

            outTokens[tokenAddress][packetData.srcChain] -= amount;

            return _newAcknowledgement(true, "");
        }

        // Base token back to origin
        if (amount > outTokens[address(0)][packetData.srcChain]) {
            return
                _newAcknowledgement(
                    false,
                    "onRecvPackt: amount could not be greater than locked amount"
                );
        }

        if (updateTimeBasedLimtSupply(tokenAddress, amount)) {
            return _newAcknowledgement(false, "onRecvPackt: invalid amount");
        }

        (bool success, ) = receiver.call{value: amount}("");
        if (!success) {
            return
                _newAcknowledgement(
                    false,
                    "onRecvPackt: unlock to receiver failed"
                );
        }

        outTokens[address(0)][packetData.srcChain] -= amount;

        return _newAcknowledgement(true, "");
    }

    /**
     * @notice if exceeded max or less than min, retrun true
     * @param tokenAddress token address
     * @param amount token amount
     */
    function updateTimeBasedLimtSupply(address tokenAddress, uint256 amount)
        internal
        returns (bool)
    {
        TransferDataTypes.TimeBasedSupplyLimit memory limit = limits[
            tokenAddress
        ];
        if (limit.enable) {
            if (amount < limit.minAmount || amount > limit.maxAmount) {
                return true;
            }
            if (block.timestamp - limit.previousTime < limit.timePeriod) {
                require(
                    limit.currentSupply + amount < limit.timeBasedLimit,
                    "exceeded time based limit"
                );

                limits[tokenAddress].currentSupply += amount;
            } else {
                limits[tokenAddress].previousTime = block.timestamp;
                limits[tokenAddress].currentSupply = amount;
            }
        }
        return false;
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
