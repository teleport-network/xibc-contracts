// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../utils/Strings.sol";

library Host {
    /**
     * @notice nextSequenceSendKey returns the store key for the send sequence of a particular
     * @param sourceChain source chain name
     * @param destChain destination chain name
     */
    function nextSequenceSendKey(
        string memory sourceChain,
        string memory destChain
    ) internal pure returns (bytes memory) {
        return bytes(packetPath(sourceChain, destChain));
    }

    /**
     * @notice packetCommitmentPath defines the next send sequence counter store path
     *  @param sourceChain source chain name
     *  @param destChain destination chain name
     *  @param sequence sequence
     */
    function packetCommitmentPath(
        string memory sourceChain,
        string memory destChain,
        uint64 sequence
    ) internal pure returns (string memory) {
        return
            Strings.strConcat(
                Strings.strConcat(
                    packetCommitmentPrefixPath(sourceChain, destChain),
                    "/"
                ),
                Strings.uint642str(sequence)
            );
    }

    /**
     * @notice packetCommitmentKey returns the store key of under which a packet commitment
     * @param sourceChain source chain name
     * @param destChain destination chain name
     * @param sequence sequence
     */
    function packetCommitmentKey(
        string memory sourceChain,
        string memory destChain,
        uint64 sequence
    ) internal pure returns (bytes memory) {
        return bytes(packetCommitmentPath(sourceChain, destChain, sequence));
    }

    /**
     * @notice packetCommitmentPrefixPath returns the store key of under which a packet commitment. should be same with teleport
     * @param sourceChain source chain name
     * @param destChain destination chain name
     */
    function packetCommitmentPrefixPath(
        string memory sourceChain,
        string memory destChain
    ) internal pure returns (string memory) {
        return
            Strings.strConcat(
                Strings.strConcat(
                    "commitments/",
                    packetPath(sourceChain, destChain)
                ),
                "/sequences"
            );
    }

    /**
     * @notice packetAcknowledgementPath defines the packet acknowledgement store path
     * @param sourceChain source chain name
     * @param destChain destination chain name
     * @param sequence sequence
     */
    function packetAcknowledgementPath(
        string memory sourceChain,
        string memory destChain,
        uint64 sequence
    ) internal pure returns (string memory) {
        return
            Strings.strConcat(
                Strings.strConcat(
                    packetAcknowledgementPrefixPath(sourceChain, destChain),
                    "/"
                ),
                Strings.uint642str(sequence)
            );
    }

    /**
     * @notice packetAcknowledgementKey returns the store key of under which a packet
     * @param sourceChain source chain name
     * @param destChain destination chain name
     * @param sequence sequence
     */
    function packetAcknowledgementKey(
        string memory sourceChain,
        string memory destChain,
        uint64 sequence
    ) internal pure returns (bytes memory) {
        return
            bytes(packetAcknowledgementPath(sourceChain, destChain, sequence));
    }

    /**
     * @notice packetAcknowledgementPrefixPath defines the prefix for commitments to packet data fields store path. should be same with teleport
     *  @param sourceChain source chain name
     *  @param destChain destination chain name
     */
    function packetAcknowledgementPrefixPath(
        string memory sourceChain,
        string memory destChain
    ) internal pure returns (string memory) {
        return
            Strings.strConcat(
                Strings.strConcat("acks/", packetPath(sourceChain, destChain)),
                "/sequences"
            );
    }

    /**
     * @notice packetReceiptPath defines the packet acknowledgement store path
     * @param sourceChain source chain name
     * @param destChain destination chain name
     * @param sequence sequence
     */
    function packetReceiptPath(
        string memory sourceChain,
        string memory destChain,
        uint64 sequence
    ) internal pure returns (string memory) {
        return
            Strings.strConcat(
                Strings.strConcat(packetPath(sourceChain, destChain), "/"),
                Strings.uint642str(sequence)
            );
    }

    /**
     * @notice packetReceiptKey returns the store key of under which a packet
     * @param sourceChain source chain name
     * @param destChain destination chain name
     * @param sequence sequence
     */
    function packetReceiptKey(
        string memory sourceChain,
        string memory destChain,
        uint64 sequence
    ) internal pure returns (bytes memory) {
        return bytes(packetReceiptPath(sourceChain, destChain, sequence));
    }

    /**
     * @notice packetPath
     * @param sourceChain source chain name
     * @param destChain destination chain name
     */
    function packetPath(string memory sourceChain, string memory destChain)
        internal
        pure
        returns (string memory)
    {
        return
            Strings.strConcat(Strings.strConcat(sourceChain, "/"), destChain);
    }

    /**
     * @notice MaxAckSeqKey returns the store key of current max ack height is stored
     * @param sourceChain source chain name
     * @param destChain destination chain name
     */
    function MaxAckSeqKey(string memory sourceChain, string memory destChain)
        internal
        pure
        returns (bytes memory)
    {
        return bytes(packetPath(sourceChain, destChain));
    }

    /**
     * @notice ackStatusKey returns the store key of ack status
     * @param sourceChain source chain name
     * @param destChain destination chain name
     * @param sequence sequence
     */
    function ackStatusKey(
        string memory sourceChain,
        string memory destChain,
        uint64 sequence
    ) internal pure returns (bytes memory) {
        return bytes(ackStatusPath(sourceChain, destChain, sequence));
    }

    /**
     * @notice ackStatusPath defines ack status store path
     *  @param sourceChain source chain name
     *  @param destChain destination chain name
     *  @param sequence sequence
     */
    function ackStatusPath(
        string memory sourceChain,
        string memory destChain,
        uint64 sequence
    ) internal pure returns (string memory) {
        return
            Strings.strConcat(
                Strings.strConcat(packetPath(sourceChain, destChain), "/"),
                Strings.uint642str(sequence)
            );
    }
}
