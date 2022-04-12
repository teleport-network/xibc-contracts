// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../../libraries/core/Result.sol";
import "../../libraries/core/Packet.sol";
import "../../libraries/app/Transfer.sol";
import "../../libraries/utils/Bytes.sol";
import "../../libraries/utils/Strings.sol";
import "../../interfaces/ITransfer.sol";
import "../../interfaces/IERC20XIBC.sol";
import "../../interfaces/IPacket.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract Transfer is ITransfer, ReentrancyGuardUpgradeable {
    using Strings for *;
    using Bytes for *;

    string private constant nativeChainName = "teleport";

    address public constant aggregateModuleAddress =
        address(0xEE3c65B5c7F4DD0ebeD8bF046725e273e3eeeD3c);
    address public constant transferModuleAddress =
        address(0xDE152Fc3Bc10A8878677FD17c44aE633D9EBF737);
    address public constant packetContractAddress =
        address(0x0000000000000000000000000000000020000001);
    address public constant multiCallContractAddress =
        address(0x0000000000000000000000000000000030000003);

    // token come in
    address[] public override boundTokens;
    mapping(address => string[]) public override boundTokenSources;
    mapping(string => TransferDataTypes.InToken) public bindings; // mapping(token/origin_chain => InToken)
    mapping(string => address) public override bindingTraces; // mapping(origin_chain/origin_token => token)

    // token out
    mapping(address => mapping(string => uint256)) public override outTokens; // mapping(token, mapping(dst_chain => amount))
    // use address(0) as base token address

    // time based supply limit
    mapping(address => TransferDataTypes.TimeBasedSupplyLimit) public limits; // mapping(token => TimeBasedSupplyLimit)

    TransferDataTypes.PacketData public latestPacket;

    // if back is true, srcToken should be set
    struct sendPacket {
        string srcChain;
        string destChain;
        string relayChain;
        uint64 sequence;
        string sender;
        string receiver;
        uint256 amount;
        string token;
        string oriToken;
    }
    event SendPacket(sendPacket packet);

    modifier onlyXIBCModuleAggregate() {
        require(
            msg.sender == address(aggregateModuleAddress),
            "caller must be xibc aggregate module"
        );
        _;
    }

    modifier onlyXIBCModuleTransfer() {
        require(
            msg.sender == address(transferModuleAddress),
            "caller must be XIBC transfer module"
        );
        _;
    }

    modifier onlyMultiCall() {
        require(
            msg.sender == multiCallContractAddress,
            "caller must be multiCall contract address"
        );
        _;
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
        string calldata oriChain,
        uint8 scale
    ) external onlyXIBCModuleAggregate {
        require(tokenAddress != address(0), "invalid ERC20 address");
        require(
            !nativeChainName.equals(oriChain),
            "oriChain can't equal to nativeChainName"
        );
        string memory bindingKey = Strings.strConcat(
            Strings.strConcat(tokenAddress.addressToString(), "/"),
            oriChain
        );
        if (bindings[bindingKey].bound) {
            // rebind
            string memory rebindKey = Strings.strConcat(
                Strings.strConcat(oriChain, "/"),
                bindings[bindingKey].oriToken
            );
            delete bindingTraces[rebindKey];
        } else {
            boundTokens.push(tokenAddress);
            boundTokenSources[tokenAddress].push(oriChain);
        }

        string memory traceKey = Strings.strConcat(
            Strings.strConcat(oriChain, "/"),
            oriToken
        );

        bindings[bindingKey] = TransferDataTypes.InToken({
            oriToken: oriToken,
            amount: 0,
            scale: scale,
            bound: true
        });
        bindingTraces[traceKey] = tokenAddress;
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
    ) external onlyXIBCModuleAggregate {
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
        onlyXIBCModuleAggregate
    {
        require(limits[tokenAddress].enable, "not enable");

        limits[tokenAddress] = TransferDataTypes.TimeBasedSupplyLimit({
            enable: false,
            timePeriod: 0,
            timeBasedLimit: 0,
            maxAmount: 0,
            minAmount: 0,
            previousTime: 0,
            currentSupply: 0
        });
    }

    function sendTransfer(
        TransferDataTypes.TransferData memory transferData,
        PacketTypes.Fee memory fee
    ) public payable override nonReentrant {
        require(
            !nativeChainName.equals(transferData.destChain),
            "sourceChain can't equal to destChain"
        );

        uint64 sequence = IPacket(packetContractAddress).getNextSequenceSend(
            nativeChainName,
            transferData.destChain
        );

        if (transferData.tokenAddress == address(0)) {
            // transfer base token

            if (fee.tokenAddress == address(0)) {
                require(
                    transferData.amount > 0 &&
                        msg.value == transferData.amount + fee.amount,
                    "invalid amount or value"
                );
                // send fee to packet
                IPacket(packetContractAddress).setPacketFee{value: fee.amount}(
                    nativeChainName,
                    transferData.destChain,
                    sequence,
                    fee
                );
            } else {
                require(
                    transferData.amount > 0 && msg.value == transferData.amount,
                    "invalid amount or value"
                );
                // send fee to packet
                require(
                    IERC20(fee.tokenAddress).transferFrom(
                        msg.sender,
                        packetContractAddress,
                        fee.amount
                    ),
                    "lock failed, unsufficient allowance"
                );
                IPacket(packetContractAddress).setPacketFee(
                    nativeChainName,
                    transferData.destChain,
                    sequence,
                    fee
                );
            }

            outTokens[address(0)][transferData.destChain] += transferData
                .amount;

            emit SendPacket(
                sendPacket({
                    srcChain: nativeChainName,
                    destChain: transferData.destChain,
                    relayChain: transferData.relayChain,
                    sequence: sequence,
                    sender: msg.sender.addressToString(),
                    receiver: transferData.receiver,
                    amount: transferData.amount,
                    token: address(0).addressToString(),
                    oriToken: ""
                })
            );
        } else {
            // transfer ERC20 token

            if (fee.tokenAddress == address(0)) {
                require(msg.value == fee.amount, "invalid fee");
                // send fee to packet
                IPacket(packetContractAddress).setPacketFee{value: fee.amount}(
                    nativeChainName,
                    transferData.destChain,
                    sequence,
                    fee
                );
            } else {
                require(msg.value == 0, "invalid value");
                // send fee to packet
                require(
                    IERC20(fee.tokenAddress).transferFrom(
                        msg.sender,
                        packetContractAddress,
                        fee.amount
                    ),
                    "lock failed, unsufficient allowance"
                );
                IPacket(packetContractAddress).setPacketFee(
                    nativeChainName,
                    transferData.destChain,
                    sequence,
                    fee
                );
            }

            string memory bindingKey = Strings.strConcat(
                Strings.strConcat(
                    transferData.tokenAddress.addressToString(),
                    "/"
                ),
                transferData.destChain
            );

            string memory oriToken;

            // if is crossed chain token
            if (bindings[bindingKey].bound) {
                // back to origin

                uint256 realAmount = transferData.amount *
                    10**uint256(bindings[bindingKey].scale);

                require(
                    bindings[bindingKey].amount >= realAmount,
                    "insufficient liquidity"
                );

                require(
                    _burn(transferData.tokenAddress, msg.sender, realAmount),
                    "burn token failed"
                );

                bindings[bindingKey].amount -= realAmount;
                oriToken = bindings[bindingKey].oriToken;
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
            emit SendPacket(
                sendPacket({
                    srcChain: nativeChainName,
                    destChain: transferData.destChain,
                    relayChain: transferData.relayChain,
                    sequence: sequence,
                    sender: msg.sender.addressToString(),
                    receiver: transferData.receiver,
                    amount: transferData.amount,
                    token: transferData.tokenAddress.addressToString(),
                    oriToken: oriToken
                })
            );
        }
    }

    function transfer(TransferDataTypes.TransferDataMulti calldata transferData)
        external
        payable
        override
        onlyMultiCall
        nonReentrant
    {
        require(
            !nativeChainName.equals(transferData.destChain),
            "sourceChain can't equal to destChain"
        );

        if (transferData.tokenAddress == address(0)) {
            // transfer base token

            require(transferData.amount == msg.value, "invalid value");
            outTokens[address(0)][transferData.destChain] += transferData
                .amount;
        } else {
            // transfer ERC20 token

            require(msg.value == 0, "invalid value");

            string memory bindingKey = Strings.strConcat(
                Strings.strConcat(
                    transferData.tokenAddress.addressToString(),
                    "/"
                ),
                transferData.destChain
            );

            // if is crossed chain token
            if (bindings[bindingKey].bound) {
                // back to origin

                uint256 realAmount = transferData.amount *
                    10**uint256(bindings[bindingKey].scale);

                require(
                    bindings[bindingKey].amount >= realAmount,
                    "insufficient liquidity"
                );

                require(
                    _burn(
                        transferData.tokenAddress,
                        transferData.sender,
                        realAmount
                    ),
                    "burn token failed"
                );

                bindings[bindingKey].amount -= realAmount;
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
            }
        }
    }

    // ===========================================================================

    function onRecvPacket(TransferDataTypes.PacketData calldata packet)
        external
        override
        nonReentrant
        onlyXIBCModuleTransfer
        returns (Result.Data memory)
    {
        latestPacket = TransferDataTypes.PacketData({
            srcChain: packet.srcChain,
            destChain: packet.destChain,
            sequence: packet.sequence,
            sender: packet.sender,
            receiver: packet.receiver,
            amount: packet.amount,
            token: packet.token,
            oriToken: packet.oriToken
        });

        address tokenAddress;
        address receiver = packet.receiver.parseAddr();
        uint256 amount = packet.amount.toUint256();

        if (bytes(packet.oriToken).length == 0) {
            // token come in
            tokenAddress = bindingTraces[
                Strings.strConcat(
                    Strings.strConcat(packet.srcChain, "/"),
                    packet.token
                )
            ];

            string memory bindingKey = Strings.strConcat(
                Strings.strConcat(tokenAddress.addressToString(), "/"),
                packet.srcChain
            );

            uint256 realAmount = amount *
                10**uint256(bindings[bindingKey].scale);

            // check bindings
            if (!bindings[bindingKey].bound) {
                return
                    _newAcknowledgement(
                        false,
                        "onRecvPackt: binding is not exist"
                    );
            }

            if (updateTimeBasedLimtSupply(tokenAddress, realAmount)) {
                return
                    _newAcknowledgement(false, "onRecvPackt: invalid amount");
            }

            if (!_mint(tokenAddress, receiver, realAmount)) {
                return _newAcknowledgement(false, "onRecvPackt: mint failed");
            }

            bindings[bindingKey].amount += realAmount;

            return _newAcknowledgement(true, "");
        }

        tokenAddress = packet.oriToken.parseAddr();
        if (tokenAddress != address(0)) {
            // ERC20 token back to origin
            if (amount > outTokens[tokenAddress][packet.srcChain]) {
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

            outTokens[tokenAddress][packet.srcChain] -= amount;

            return _newAcknowledgement(true, "");
        }

        // Base token back to origin
        if (amount > outTokens[address(0)][packet.srcChain]) {
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

        outTokens[address(0)][packet.srcChain] -= amount;

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

    function onAcknowledgementPacket(
        TransferDataTypes.PacketData calldata packet,
        bytes calldata result
    ) external override nonReentrant onlyXIBCModuleTransfer {
        if (!Bytes.equals(result, hex"01")) {
            if (bytes(packet.oriToken).length > 0) {
                // refund crossed chain token back to origin

                string memory bindingKey = Strings.strConcat(
                    Strings.strConcat(packet.token, "/"),
                    packet.destChain
                );

                uint256 realAmount = packet.amount.toUint256() *
                    10**uint256(bindings[bindingKey].scale);

                require(
                    _mint(
                        packet.token.parseAddr(),
                        packet.sender.parseAddr(),
                        realAmount
                    ),
                    "mint back to sender failed"
                );
                bindings[bindingKey].amount += realAmount;
            } else if (packet.token.parseAddr() != address(0)) {
                // refund native ERC20 token out
                require(
                    IERC20(packet.token.parseAddr()).transfer(
                        packet.sender.parseAddr(),
                        packet.amount.toUint256()
                    ),
                    "unlock to sender failed"
                );
                outTokens[packet.token.parseAddr()][packet.destChain] -= packet
                    .amount
                    .toUint256();
            } else {
                // refund base token out
                (bool success, ) = packet.sender.parseAddr().call{
                    value: packet.amount.toUint256()
                }("");
                require(success, "unlock base token to sender failed");
                outTokens[address(0)][packet.destChain] -= packet
                    .amount
                    .toUint256();
            }
        }
    }

    function _newAcknowledgement(bool success, string memory errMsg)
        private
        pure
        returns (Result.Data memory)
    {
        Result.Data memory ack;
        if (success) {
            ack.result = hex"01";
        } else {
            ack.message = errMsg;
        }
        return ack;
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
        returns (TransferDataTypes.PacketData memory)
    {
        return latestPacket;
    }

    function getBindings(string calldata key)
        external
        view
        override
        returns (TransferDataTypes.InToken memory)
    {
        return bindings[key];
    }
}
