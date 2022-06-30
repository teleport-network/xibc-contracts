// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

interface IAccessManager {
    /**
     * @notice returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external returns (bool);
}
