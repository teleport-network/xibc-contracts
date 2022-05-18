// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../../libraries/packet/Packet.sol";
import "../../libraries/crosschain/CrossChain.sol";
import "../../libraries/utils/Bytes.sol";
import "../../libraries/utils/Strings.sol";
import "../../interfaces/ICrossChain.sol";
import "../../interfaces/IERC20XIBC.sol";
import "../../interfaces/IPacket.sol";
import "../../interfaces/ICallback.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract CrossChain is ICrossChain, ReentrancyGuardUpgradeable {
    using Strings for *;
    using Bytes for *;

    string private constant nativeChainName = "teleport";

    address public constant aggregateModuleAddress =
        address(0xEE3c65B5c7F4DD0ebeD8bF046725e273e3eeeD3c);
    address public constant packetContractAddress =
        address(0x0000000000000000000000000000000020000001);

    // token come in
    address[] public override boundTokens;
    mapping(address => string[]) public override boundTokenSources;
    mapping(string => TransferDataTypes.InToken) public bindings; // mapping(token/origin_chain => InToken)
    mapping(string => address) public override bindingTraces; // mapping(origin_chain/origin_token => token)

    // token out. use address(0) as base token address
    mapping(address => mapping(string => uint256)) public override outTokens; // mapping(token, mapping(dst_chain => amount))

    // time based supply limit
    mapping(address => TransferDataTypes.TimeBasedSupplyLimit) public limits; // mapping(token => TimeBasedSupplyLimit)

    modifier onlyXIBCModuleAggregate() {
        require(
            msg.sender == address(aggregateModuleAddress),
            "caller must be xibc aggregate module"
        );
        _;
    }

    modifier onlyPacket() {
        require(
            msg.sender == packetContractAddress,
            "caller must be packet contract"
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
        delete limits[tokenAddress];
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

    /**
     * @notice todo
     */
    function crossChainCall(
        CrossChainDataTypes.CrossChainData memory crossChainData,
        PacketTypes.Fee memory fee
    ) public payable override nonReentrant {
        // TODO
    }

    /**
     * @notice todo
     */
    function onRecvPacket(PacketTypes.PacketData calldata packetData)
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
        // TODO
    }

    function onAcknowledgementPacket(
        PacketTypes.PacketData memory packetData,
        uint64 code,
        bytes memory result,
        string memory message
    ) public override nonReentrant onlyPacket {
        if (code != 0) {
            _refundTokens(packetData);
        }
        ICallback(packetData.callbackAddress.parseAddr()).callback(
            code,
            result,
            message
        );
    }

    function _refundTokens(PacketTypes.PacketData memory packetData) private {
        PacketTypes.TransferData memory transferData = abi.decode(
            packetData.transferData,
            (PacketTypes.TransferData)
        );

        address sender = packetData.sender.parseAddr();
        address tokenAddress = transferData.token.parseAddr();
        uint256 amount = transferData.amount.toUint256();

        if (bytes(transferData.oriToken).length > 0) {
            // refund crossed chain token back to origin
            string memory bindingKey = Strings.strConcat(
                Strings.strConcat(transferData.token, "/"),
                packetData.destChain
            );
            uint256 realAmount = amount *
                10**uint256(bindings[bindingKey].scale);
            require(
                _mint(tokenAddress, sender, realAmount),
                "mint back to sender failed"
            );
            bindings[bindingKey].amount += realAmount;
        } else if (tokenAddress != address(0)) {
            // refund native ERC20 token out
            require(
                IERC20(tokenAddress).transfer(sender, amount),
                "unlock to sender failed"
            );
            outTokens[tokenAddress][packetData.destChain] -= amount;
        } else {
            // refund base token out
            (bool success, ) = sender.call{value: amount}("");
            require(success, "unlock base token to sender failed");
            outTokens[tokenAddress][packetData.destChain] -= amount;
        }
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

    /**
     * @notice todo
     */
    function getBindings(string calldata key)
        external
        view
        override
        returns (TransferDataTypes.InToken memory)
    {
        return bindings[key];
    }
}
