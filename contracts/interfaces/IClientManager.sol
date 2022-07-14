// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import "./IClient.sol";

interface IClientManagerRC {
    /**
     * @notice get client
     *  @param chain chain name
     * @return returns the client instance
     */
    function clients(string calldata chain) external view returns (IClient);

    /**
     * @notice get the client type
     * @param chain client chain name
     * @return returns the client type
     */
    function getClientType(string calldata chain) external view returns (IClient.Type);

    /**
     * @notice get the current latest height of the client
     * @param chain client chain name
     * @return return the current latest height of the client
     */
    function getLatestHeight(string calldata chain) external view returns (Height.Data memory);

    /**
     * @notice authenticate the relayer
     * @return return the relayer is registerd or not
     */
    function authRelayer(address relayer) external view returns (bool);

    /**
     * @notice getRelayerChainAddress returns the chain address of the relayer
     * @return return the relayer address on the specified chain
     */
    function getRelayerChainAddress(address relayer, string calldata chain) external view returns (string memory);

    /**
     * @notice getRelayerByChainAddress returns the relayer address
     * @return return the relayer by the specified chain and address
     */
    function getRelayerByChainAddress(string calldata chain, string calldata addr) external view returns (address);
}

interface IClientManagerAC {
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
