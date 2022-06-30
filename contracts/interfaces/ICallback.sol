// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

interface ICallback {
    /**
     * @notice callback function. This function is called when the packet is received. This method may be called by others, please ensure a single consumption in implemention.
     * @param srcChain source chain
     * @param dstChain destination chain
     * @param sequence packet sequence
     * @param code error code
     * @param result packet result
     * @param message error message
     */
    function callback(
        string calldata srcChain,
        string calldata dstChain,
        uint64 sequence,
        uint64 code,
        bytes calldata result,
        string calldata message
    ) external;
}
