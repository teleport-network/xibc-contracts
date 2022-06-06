// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

interface IAccessManager {
    /**
     * @notice todo
     */
    function hasRole(bytes32 role, address account) external returns (bool);
}