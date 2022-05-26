// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

interface ICallback {
    /**
     * @notice todo
     */
    function callback(
        string calldata srcChain,
        string calldata destChain,
        uint64 sequence,
        uint64 code,
        bytes calldata result,
        string calldata message
    ) external;
}
