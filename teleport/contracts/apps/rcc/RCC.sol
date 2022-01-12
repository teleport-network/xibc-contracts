// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../../libraries/core/Result.sol";
import "../../libraries/app/RCC.sol";
import "../../libraries/utils/Bytes.sol";
import "../../libraries/utils/Strings.sol";
import "../../interfaces/IRCC.sol";

contract RCC is IRCC {
    using Strings for *;
    using Bytes for *;

    string private constant nativeChainName = "teleport";

    address public constant xibcModuleRCC =
        address(0xfef812Ed2Bf63E7eE056931d54A6292fcbbaDFaA);

    address public constant multiCallAddress =
        address(0x0000000000000000000000000000000010000005);

    mapping(bytes32 => bytes) public acks;

    RCCDataTypes.PacketData public latestPacket;

    event SendPacket(
        string srcChain,
        string destChain,
        string relayChain,
        string sender,
        string contractAddress,
        bytes data
    );

    event Ack(bytes32 indexed dataHash, bytes ack);

    modifier onlyXIBCModuleRCC() {
        require(msg.sender == xibcModuleRCC, "caller must be XIBC RCC module");
        _;
    }

    modifier onlyMultiCall() {
        require(
            msg.sender == multiCallAddress,
            "caller must be multiCall contract address"
        );
        _;
    }

    function sendRemoteContractCall(RCCDataTypes.RCCData calldata rccData)
        external
        override
    {
        require(
            !nativeChainName.equals(rccData.destChain),
            "sourceChain can't equal to destChain"
        );

        // TODO: validate rcc data

        emit SendPacket(
            nativeChainName,
            rccData.destChain,
            rccData.relayChain,
            msg.sender.addressToString(),
            rccData.contractAddress,
            rccData.data
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
            result.message = "onRecvPackt: execute packet failed";
        } else {
            result.result = res;
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
}
