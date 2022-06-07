// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./IClient.sol";

interface IClientManager {
    /**
     * @notice get client
     * @return returns the client instance
     */
    function client() external view returns (IClient);

    /**
     * @notice get the client type
     * @return returns the client type
     */
    function getClientType() external view returns (IClient.Type);

    /**
     * @notice get the current latest height of the client
     * @return return the current latest height of the client
     */
    function getLatestHeight() external view returns (Height.Data memory);
}
