// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../libraries/packet/Packet.sol";

interface IPacket {
    /**
     * @notice get the name of this chain
     * @return returns the name of this chain
     */
    function chainName() external view returns (string memory);

    /**
     * @notice send cross-chain data packets
     * @param packet xibc packet
     * @param fee packet fee
     */
    function sendPacket(PacketTypes.Packet calldata packet, PacketTypes.Fee calldata fee) external payable;

    /**
     * @notice get the next sequence of srcChain/dstChain
     * @param dstChain destination chain name
     */
    function getNextSequenceSend(string calldata dstChain) external view returns (uint64);

    /**
     * @notice get the next sequence of dstChain
     * @param dstChain destination chain name
     * @param sequence sequence
     */
    function getAckStatus(string calldata dstChain, uint64 sequence) external view returns (uint8);

    /**
     * @notice todo
     */
    function getLatestPacket() external view returns (PacketTypes.Packet memory packet);
}
