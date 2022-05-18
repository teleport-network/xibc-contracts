// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../libraries/packet/Packet.sol";
import "../proto/Types.sol";

interface IPacket {
    /**
     * @notice send cross-chain data packets
     * @param packetData xibc packet data
     * @param fee packet fee
     */
    function sendPacket(
        PacketTypes.PacketData calldata packetData,
        PacketTypes.Fee calldata fee
    ) external payable;

    /**
     * @notice receive cross-chain data packets from the sending chain
     * @param packet cross-chain data packets
     * @param proof proof of the existence of packet on the original chain
     * @param proof height of the proof
     */
    function recvPacket(
        PacketTypes.Packet calldata packet,
        bytes calldata proof,
        Height.Data calldata height
    ) external;

    /**
     * @notice receive cross-chain data packets from the sending chain
     * @param packet cross-chain data packets
     * @param acknowledgement confirmation message of packet on the receiving chain
     * @param proofAcked existence proof of acknowledgement on the receiving chain
     * @param height height of the proof
     */
    function acknowledgePacket(
        PacketTypes.Packet calldata packet,
        bytes calldata acknowledgement,
        bytes calldata proofAcked,
        Height.Data calldata height
    ) external;

    /**
     * @notice get the next sequence of sourceChain/destChain
     * @param sourceChain source chain name
     * @param destChain destination chain name
     */
    function getNextSequenceSend(
        string calldata sourceChain,
        string calldata destChain
    ) external view returns (uint64);

    /**
     * @notice get the next sequence of sourceChain/destChain
     * @param sourceChain source chain name
     * @param destChain destination chain name
     * @param sequence sequence
     */
    function getAckStatus(
        string calldata sourceChain,
        string calldata destChain,
        uint64 sequence
    ) external view returns (uint8);

    /**
     * @notice todo
     */
    function getLatestPacketData()
        external
        view
        returns (PacketTypes.PacketData memory packetData);
}
