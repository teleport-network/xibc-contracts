// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import "../libraries/endpoint/Endpoint.sol";
import "../libraries/packet/Packet.sol";

interface IEndpoint {
    /**
     * @notice send cross chain call
     * @param crossChainData cross chain data
     * @param fee cross chain fee
     */
    function crossChainCall(CrossChainDataTypes.CrossChainData calldata crossChainData, PacketTypes.Fee calldata fee)
        external
        payable;

    /**
     * @notice onRecvPacket is called by XIBC packet module in order to receive & process an XIBC packet
     * @param packet xibc packet
     */
    function onRecvPacket(PacketTypes.Packet calldata packet)
        external
        returns (
            uint64 code,
            bytes memory result,
            string memory message
        );

    /**
     * @notice acknowledge packet in order to receive an XIBC acknowledgement
     * @param code error code
     * @param result packet execution result
     * @param message error message
     */
    function onAcknowledgementPacket(
        PacketTypes.Packet calldata packet,
        uint64 code,
        bytes calldata result,
        string calldata message
    ) external;

    /**
     * @notice returns bound token by index
     */
    function boundTokens(uint256 index) external view returns (address tokenAddress);

    /**
     * @notice returns token address by traces
     */
    function bindingTraces(string calldata trace) external view returns (address tokenAddress);

    /**
     * @notice returns token out amount
     * @param tokenAddress token address
     * @param dstChain destination chain name
     */
    function outTokens(address tokenAddress, string calldata dstChain) external view returns (uint256 amount);

    /**
     * @notice returns token binding by key
     */
    function getBindings(string calldata key) external view returns (TokenBindingTypes.Binding memory binding);
}
