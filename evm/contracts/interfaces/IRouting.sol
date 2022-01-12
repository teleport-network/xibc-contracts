// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "./IModule.sol";

interface IRouting {
    /**
     * @notice get application contract instance
     * @param port port of app module
     */
    function getModule(string calldata port) external view returns (IModule);
}
