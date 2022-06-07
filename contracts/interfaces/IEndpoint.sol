// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import "../libraries/endpoint/Endpoint.sol";
import "../libraries/packet/Packet.sol";

interface IEndpoint {
    /**
     * @notice todo
     */
    function crossChainCall(CrossChainDataTypes.CrossChainData calldata crossChainData, PacketTypes.Fee calldata fee)
        external
        payable;

    /**
     * @notice todo
     */
    function onRecvPacket(PacketTypes.Packet calldata packet)
        external
        returns (
            uint64 code,
            bytes memory result,
            string memory message
        );

    /**
     * @notice todo
     */
    function onAcknowledgementPacket(
        PacketTypes.Packet calldata packet,
        uint64 code,
        bytes calldata result,
        string calldata message
    ) external;

    /**
     * @notice todo
     */
    function boundTokens(uint256 index) external view returns (address tokenAddress);

    /**
     * @notice todo
     */
    function bindingTraces(string calldata trace) external view returns (address tokenAddress);

    /**
     * @notice todo
     */
    function outTokens(address tokenAddress, string calldata dstChain) external view returns (uint256 amount);

    /**
     * @notice todo
     */
    function getBindings(string calldata key) external view returns (TokenBindingTypes.Binding memory binding);
}
