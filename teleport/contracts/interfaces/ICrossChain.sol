// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../libraries/crosschain/CrossChain.sol";
import "../libraries/packet/Packet.sol";

interface ICrossChain {
    /**
     * @notice todo
     */
    function crossChainCall(
        CrossChainDataTypes.CrossChainData calldata crossChainData,
        PacketTypes.Fee calldata fee
    ) external payable;

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
    function boundTokens(uint256 index)
        external
        pure
        returns (address tokenAddress);

    /**
     * @notice todo
     */
    function boundTokenSources(address tokenAddress, uint256 index)
        external
        pure
        returns (string memory tokenSource);

    /**
     * @notice todo
     */
    function bindingTraces(string calldata trace)
        external
        pure
        returns (address tokenAddress);

    /**
     * @notice todo
     */
    function outTokens(address tokenAddress, string calldata destChain)
        external
        pure
        returns (uint256 amount);

    /**
     * @notice todo
     */
    function getBindings(string calldata path)
        external
        view
        returns (TransferDataTypes.InToken memory binding);
}
