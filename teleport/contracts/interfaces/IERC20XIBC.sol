// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

interface IERC20XIBC {
    /**
     * @notice todo
     */
    function mint(address to, uint256 amount) external;

    /**
     * @notice todo
     */
    function burnFrom(address account, uint256 amount) external;

    /**
     * @notice todo
     */
    function decimals() external view returns (uint8);
}
