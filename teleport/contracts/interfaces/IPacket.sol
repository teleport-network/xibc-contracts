// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

interface IPacket {
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
}
