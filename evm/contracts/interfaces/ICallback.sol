// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

interface ICallBack {
    function callback(
        uint64 code,
        bytes calldata result,
        string calldata message
    ) external;
}
