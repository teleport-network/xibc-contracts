// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../../libraries/core/Result.sol";
import "../../libraries/core/Packet.sol";
import "../../libraries/app/RCC.sol";
import "../../libraries/utils/Bytes.sol";
import "../../libraries/utils/Strings.sol";
import "../../interfaces/IRCC.sol";
import "../../interfaces/IPacket.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract RCC is IRCC, ReentrancyGuardUpgradeable {
    using Strings for *;
    using Bytes for *;

    string private constant nativeChainName = "teleport";

    address public constant packetContractAddress =
        address(0x0000000000000000000000000000000020000001);
    address public constant rccContractAddress =
        address(0xfef812Ed2Bf63E7eE056931d54A6292fcbbaDFaA);
    address public constant multiCallContractAddress =
        address(0x0000000000000000000000000000000030000003);

    mapping(bytes32 => bytes) public override acks;

    RCCDataTypes.PacketData public latestPacket;

    struct sendPacket {
        string srcChain;
        string destChain;
        string relayChain;
        uint64 sequence;
        string sender;
        string contractAddress;
        bytes data;
    }
    event SendPacket(sendPacket packet);

    event Ack(bytes32 indexed dataHash, bytes ack);

    modifier onlyXIBCModuleRCC() {
        require(
            msg.sender == rccContractAddress,
            "caller must be XIBC RCC module"
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

    function sendRemoteContractCall(
        RCCDataTypes.RCCData memory rccData,
        PacketTypes.Fee memory fee
    ) public payable override {
        require(
            !nativeChainName.equals(rccData.destChain),
            "sourceChain can't equal to destChain"
        );

        uint64 sequence = IPacket(packetContractAddress).getNextSequenceSend(
            nativeChainName,
            rccData.destChain
        );

        if (fee.tokenAddress == address(0)) {
            require(msg.value == fee.amount, "invalid value");
            // send fee to packet
            IPacket(packetContractAddress).setPacketFee{value: fee.amount}(
                nativeChainName,
                rccData.destChain,
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
                rccData.destChain,
                sequence,
                fee
            );
        }

        emit SendPacket(
            sendPacket({
                srcChain: nativeChainName,
                destChain: rccData.destChain,
                relayChain: rccData.relayChain,
                sequence: sequence,
                sender: msg.sender.addressToString(),
                contractAddress: rccData.contractAddress,
                data: rccData.data
            })
        );
    }

    function remoteContractCall(RCCDataTypes.RCCDataMulti calldata rccData)
        external
        override
        onlyMultiCall
    {
        require(
            !nativeChainName.equals(rccData.destChain),
            "sourceChain can't equal to destChain"
        );

        // TODO: validate rcc data
    }

    // ===========================================================================

    function onRecvPacket(RCCDataTypes.PacketData calldata packet)
        external
        override
        nonReentrant
        onlyXIBCModuleRCC
        returns (Result.Data memory)
    {
        require(
            packet.contractAddress.parseAddr() != address(this),
            "illegal operation"
        );

        latestPacket = RCCDataTypes.PacketData({
            srcChain: packet.srcChain,
            destChain: packet.destChain,
            sequence: packet.sequence,
            sender: packet.sender,
            contractAddress: packet.contractAddress,
            data: packet.data
        });

        Result.Data memory result;
        (bool success, bytes memory res) = packet
            .contractAddress
            .parseAddr()
            .call(packet.data);
        if (!success) {
            if (res.length != 0) {
                result.message = string(res);
            } else {
                result.message = "onRecvPackt: execute packet failed";
            }
        } else {
            if (res.length == 0) {
                result.result = hex"01";
            } else {
                result.result = res;
            }
        }

        return result;
    }

    function onAcknowledgementPacket(bytes32 dataHash, bytes calldata result)
        external
        override
        onlyXIBCModuleRCC
    {
        acks[dataHash] = result;
        emit Ack(dataHash, result);
    }

    // ===========================================================================

    function getLatestPacket()
        external
        view
        override
        returns (RCCDataTypes.PacketData memory)
    {
        return latestPacket;
    }
}
