// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

interface IERC20XIBC {
    /**
     * @notice mint token. only for xibc
     */
    function mint(address to, uint256 amount) external;

    /**
     * @notice burn coin. only for xibc
     */
    function burnFrom(address account, uint256 amount) external;
}
