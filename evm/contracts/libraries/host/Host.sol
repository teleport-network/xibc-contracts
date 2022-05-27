// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../utils/Strings.sol";

library Host {
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
                    Strings.strConcat(
                        Strings.strConcat(
                            "commitments/",
                            Strings.strConcat(Strings.strConcat(sourceChain, "/"), destChain)
                        ),
                        "/sequences"
                    ),
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

    // ================================================================

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
                    Strings.strConcat(
                        Strings.strConcat("acks/", Strings.strConcat(Strings.strConcat(sourceChain, "/"), destChain)),
                        "/sequences"
                    ),
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
        return bytes(packetAcknowledgementPath(sourceChain, destChain, sequence));
    }

    // ================================================================

    /**
     * @notice packetReceiptPath defines the packet acknowledgement store path
     * @param sourceChain source chain name
     * @param sequence sequence
     */
    function packetReceiptPath(string memory sourceChain, uint64 sequence) internal pure returns (string memory) {
        return Strings.strConcat(Strings.strConcat(sourceChain, "/"), Strings.uint642str(sequence));
    }

    /**
     * @notice packetReceiptKey returns the store key of under which a packet
     * @param sourceChain source chain name
     * @param sequence sequence
     */
    function packetReceiptKey(string memory sourceChain, uint64 sequence) internal pure returns (bytes memory) {
        return bytes(packetReceiptPath(sourceChain, sequence));
    }

    // ================================================================

    /**
     * @notice ackStatusKey returns the store key of ack status
     * @param sourceChain source chain name
     * @param destChain destination chain name
     * @param sequence sequence
     */
    function commonUniqueKey(
        string memory sourceChain,
        string memory destChain,
        uint64 sequence
    ) internal pure returns (bytes memory) {
        return bytes(commonUniquePath(sourceChain, destChain, sequence));
    }

    /**
     * @notice ackStatusPath defines ack status store path
     *  @param sourceChain source chain name
     *  @param destChain destination chain name
     *  @param sequence sequence
     */
    function commonUniquePath(
        string memory sourceChain,
        string memory destChain,
        uint64 sequence
    ) internal pure returns (string memory) {
        return
            Strings.strConcat(
                Strings.strConcat(Strings.strConcat(Strings.strConcat(sourceChain, "/"), destChain), "/"),
                Strings.uint642str(sequence)
            );
    }
}
