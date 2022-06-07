// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import "../../../../libraries/utils/Bytes.sol";
import "../../../../libraries/utils/Strings.sol";
import "../../../../interfaces/IEndpoint.sol";
import "../../../../interfaces/IERC20XIBC.sol";
import "../../../../interfaces/IPacket.sol";
import "../../../../interfaces/ICallback.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract Endpoint is IEndpoint, ReentrancyGuardUpgradeable {
    using Strings for *;
    using Bytes for *;

    address public constant aggregateModuleAddress = address(0xEE3c65B5c7F4DD0ebeD8bF046725e273e3eeeD3c);
    address public constant packetContractAddress = address(0x0000000000000000000000000000000020000001);

    // token come in
    address[] public override boundTokens;
    mapping(address => string[]) public boundTokenSources;
    mapping(string => TokenBindingTypes.Binding) public bindings; // mapping(token/origin_chain => Binding)
    mapping(string => address) public override bindingTraces; // mapping(origin_chain/origin_token => token)

    // token out. use address(0) as base token address
    mapping(address => mapping(string => uint256)) public override outTokens; // mapping(token, mapping(dst_chain => amount))

    // time based supply limit
    mapping(address => TokenBindingTypes.TimeBasedSupplyLimit) public limits; // mapping(token => TimeBasedSupplyLimit)

    modifier onlyXIBCModuleAggregate() {
        require(msg.sender == address(aggregateModuleAddress), "caller must be xibc aggregate module");
        _;
    }

    modifier onlyPacket() {
        require(msg.sender == packetContractAddress, "caller must be packet contract");
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
            !oriChain.equals(IPacket(packetContractAddress).chainName()),
            "oriChain can't equal to nativeChainName"
        );
        string memory bindingKey = Strings.strConcat(Strings.strConcat(tokenAddress.addressToString(), "/"), oriChain);
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

        string memory traceKey = Strings.strConcat(Strings.strConcat(oriChain, "/"), oriToken);

        bindings[bindingKey] = TokenBindingTypes.Binding({
            oriChain: oriChain,
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
            timePeriod > 0 && minAmount > 0 && maxAmount > minAmount && timeBasedLimit > maxAmount,
            "invalid limit"
        );

        limits[tokenAddress] = TokenBindingTypes.TimeBasedSupplyLimit({
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
    function disableTimeBasedSupplyLimit(address tokenAddress) external onlyXIBCModuleAggregate {
        require(limits[tokenAddress].enable, "not enable");
        delete limits[tokenAddress];
    }

    /**
     * @notice if exceeded max or less than min, retrun true
     * @param tokenAddress token address
     * @param amount token amount
     */
    function _updateTimeBasedLimtSupply(address tokenAddress, uint256 amount) private returns (bool) {
        TokenBindingTypes.TimeBasedSupplyLimit memory limit = limits[tokenAddress];
        if (limit.enable) {
            if (amount < limit.minAmount || amount > limit.maxAmount) {
                return true;
            }
            if (block.timestamp - limit.previousTime < limit.timePeriod) {
                require(limit.currentSupply + amount < limit.timeBasedLimit, "exceeded time based limit");

                limits[tokenAddress].currentSupply += amount;
            } else {
                limits[tokenAddress].previousTime = block.timestamp;
                limits[tokenAddress].currentSupply = amount;
            }
        }
        return false;
    }

    /**
     * @notice todo
     */
    function crossChainCall(CrossChainDataTypes.CrossChainData memory crossChainData, PacketTypes.Fee memory fee)
        public
        payable
        override
        nonReentrant
    {
        string memory srcChain = IPacket(packetContractAddress).chainName();
        require(!crossChainData.dstChain.equals(srcChain), "invalid dstChain");
        uint64 sequence = IPacket(packetContractAddress).getNextSequenceSend(crossChainData.dstChain);

        // tansfer data and contractcall data can't be both empty
        require(crossChainData.amount != 0 || crossChainData.callData.length != 0, "invalid data");

        bytes memory transferData;
        bytes memory callData;

        // validate transfer data contract call data
        if (crossChainData.callData.length != 0) {
            require(bytes(crossChainData.contractAddress).length > 0, "invalid contract address");

            callData = abi.encode(
                PacketTypes.CallData({
                    contractAddress: crossChainData.contractAddress,
                    callData: crossChainData.callData
                })
            );
        }

        uint256 msgValue = 0;
        if (fee.tokenAddress == address(0)) {
            // add fee amount to value
            msgValue += fee.amount;
        } else if (fee.amount > 0) {
            // send fee to packet
            require(
                IERC20(fee.tokenAddress).transferFrom(msg.sender, packetContractAddress, fee.amount),
                "send fee failed, insufficient allowance"
            );
        }
        if (crossChainData.amount != 0) {
            // validate transfer data
            require(bytes(crossChainData.receiver).length > 0, "invalid receiver");
            string memory oriToken = "";
            if (crossChainData.tokenAddress == address(0)) {
                // transfer base token
                require(msg.value == crossChainData.amount + msgValue, "invalid value");
                outTokens[address(0)][crossChainData.dstChain] += crossChainData.amount;
            } else {
                // transfer ERC20

                string memory bindingKey = Strings.strConcat(
                    Strings.strConcat(crossChainData.tokenAddress.addressToString(), "/"),
                    crossChainData.dstChain
                );

                // if transfer crossed chain token
                if (bindings[bindingKey].bound) {
                    // back to origin
                    uint256 realAmount = crossChainData.amount * 10**uint256(bindings[bindingKey].scale);

                    require(bindings[bindingKey].amount >= realAmount, "insufficient liquidity");
                    require(_burn(crossChainData.tokenAddress, msg.sender, realAmount), "burn token failed");

                    bindings[bindingKey].amount -= realAmount;
                    oriToken = bindings[bindingKey].oriToken;
                } else {
                    // outgoing
                    require(
                        IERC20(crossChainData.tokenAddress).transferFrom(
                            msg.sender,
                            address(this),
                            crossChainData.amount
                        ),
                        "lock failed, insufficient allowance"
                    );
                    outTokens[crossChainData.tokenAddress][crossChainData.dstChain] += crossChainData.amount;
                }
            }

            transferData = abi.encode(
                PacketTypes.TransferData({
                    token: crossChainData.tokenAddress.addressToString(),
                    oriToken: oriToken,
                    amount: crossChainData.amount.toBytes(),
                    receiver: crossChainData.receiver
                })
            );
        }

        PacketTypes.Packet memory packet = PacketTypes.Packet({
            srcChain: srcChain,
            dstChain: crossChainData.dstChain,
            sequence: sequence,
            sender: msg.sender.addressToString(),
            transferData: transferData,
            callData: callData,
            callbackAddress: crossChainData.callbackAddress.addressToString(),
            feeOption: crossChainData.feeOption
        });

        IPacket(packetContractAddress).sendPacket{value: msgValue}(packet, fee);
    }

    /**
     * @notice todo
     */
    function onRecvPacket(PacketTypes.Packet calldata packet)
        external
        override
        nonReentrant
        onlyPacket
        returns (
            uint64 code,
            bytes memory result,
            string memory message
        )
    {
        PacketTypes.TransferData memory transferData = abi.decode(packet.transferData, (PacketTypes.TransferData));

        address tokenAddress;
        address receiver = transferData.receiver.parseAddr();
        uint256 amount = transferData.amount.toUint256();
        if (bytes(transferData.oriToken).length == 0) {
            // token come in
            tokenAddress = bindingTraces[
                Strings.strConcat(Strings.strConcat(packet.srcChain, "/"), transferData.token)
            ];
            string memory bindingKey = Strings.strConcat(
                Strings.strConcat(tokenAddress.addressToString(), "/"),
                packet.srcChain
            );
            uint256 realAmount = amount * 10**uint256(bindings[bindingKey].scale);

            // check bindings
            if (!bindings[bindingKey].bound) {
                return (2, "", "token not bound");
            }
            if (_updateTimeBasedLimtSupply(tokenAddress, realAmount)) {
                return (2, "", "invalid amount");
            }
            if (!_mint(tokenAddress, receiver, realAmount)) {
                return (2, "", "mint failed");
            }
            bindings[bindingKey].amount += realAmount;
        } else {
            tokenAddress = transferData.oriToken.parseAddr();

            if (tokenAddress != address(0)) {
                // ERC20 token back to origin
                if (amount > outTokens[tokenAddress][packet.srcChain]) {
                    return (2, "", "amount is greater than locked");
                }
                if (_updateTimeBasedLimtSupply(tokenAddress, amount)) {
                    return (2, "", "exceed the limit");
                }
                if (!IERC20(tokenAddress).transfer(receiver, amount)) {
                    return (2, "", "unlock to receiver failed");
                }
                outTokens[tokenAddress][packet.srcChain] -= amount;
            } else {
                // Base token back to origin
                if (amount > outTokens[address(0)][packet.srcChain]) {
                    return (2, "", "amount is greater than locked");
                }
                if (_updateTimeBasedLimtSupply(tokenAddress, amount)) {
                    return (2, "", "exceed the limit");
                }
                (bool success, ) = receiver.call{value: amount}("");
                if (!success) {
                    return (2, "", "unlock to receiver failed");
                }
                outTokens[address(0)][packet.srcChain] -= amount;
            }
        }

        return (0, "", "");
    }

    function onAcknowledgementPacket(
        PacketTypes.Packet memory packet,
        uint64 code,
        bytes memory result,
        string memory message
    ) public override nonReentrant onlyPacket {
        if (code != 0) {
            // refund tokens
            PacketTypes.TransferData memory transferData = abi.decode(packet.transferData, (PacketTypes.TransferData));

            address sender = packet.sender.parseAddr();
            address tokenAddress = transferData.token.parseAddr();
            uint256 amount = transferData.amount.toUint256();

            if (bytes(transferData.oriToken).length > 0) {
                // refund crossed chain token back to origin
                string memory bindingKey = Strings.strConcat(
                    Strings.strConcat(transferData.token, "/"),
                    packet.dstChain
                );
                uint256 realAmount = amount * 10**uint256(bindings[bindingKey].scale);
                require(_mint(tokenAddress, sender, realAmount), "mint back to sender failed");
                bindings[bindingKey].amount += realAmount;
            } else if (tokenAddress != address(0)) {
                // refund native ERC20 token out
                require(IERC20(tokenAddress).transfer(sender, amount), "unlock to sender failed");
                outTokens[tokenAddress][packet.dstChain] -= amount;
            } else {
                // refund base token out
                (bool success, ) = sender.call{value: amount}("");
                require(success, "unlock base token to sender failed");
                outTokens[tokenAddress][packet.dstChain] -= amount;
            }
        }
        if (packet.callbackAddress.parseAddr() != address(0)) {
            ICallback(packet.callbackAddress.parseAddr()).callback(
                packet.srcChain,
                packet.dstChain,
                packet.sequence,
                code,
                result,
                message
            );
        }
    }

    // ===========================================================================

    /**
     * @notice todo
     */
    function _burn(
        address dstContract,
        address account,
        uint256 amount
    ) private returns (bool) {
        try IERC20XIBC(dstContract).burnFrom(account, amount) {
            return true;
        } catch (bytes memory) {
            return false;
        }
    }

    /**
     * @notice todo
     */
    function _mint(
        address dstContract,
        address to,
        uint256 amount
    ) private returns (bool) {
        try IERC20XIBC(dstContract).mint(to, amount) {
            return true;
        } catch (bytes memory) {
            return false;
        }
    }

    // ===========================================================================

    /**
     * @notice todo
     */
    function getBindings(string calldata key) external view override returns (TokenBindingTypes.Binding memory) {
        return bindings[key];
    }
}
