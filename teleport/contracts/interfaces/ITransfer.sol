// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../libraries/app/Transfer.sol";
import "../libraries/core/Result.sol";

interface ITransfer {
    function sendTransferERC20(
        TransferDataTypes.ERC20TransferData calldata transferData
    ) external;

    function sendTransferBase(
        TransferDataTypes.BaseTransferData calldata transferData
    ) external payable;

    function transferERC20(
        TransferDataTypes.ERC20TransferDataMulti calldata transferData
    ) external;

    function transferBase(
        TransferDataTypes.BaseTransferDataMulti calldata transferData
    ) external payable;

    function onRecvPacket(TransferDataTypes.PacketData calldata packet)
        external
        returns (Result.Data memory);

    function onAcknowledgementPacket(
        TransferDataTypes.PacketData calldata packet,
        bytes calldata result
    ) external;

    function boundTokens(uint256) external pure returns (address);

    function boundTokenSources(address, uint256)
        external
        pure
        returns (string memory);

    function bindingTraces(string calldata) external pure returns (address);

    function outTokens(address, string calldata)
        external
        pure
        returns (uint256);

    function getBindings(string calldata)
        external
        view
        returns (TransferDataTypes.InToken memory);

    function getLatestPacket()
        external
        view
        returns (TransferDataTypes.PacketData memory);
}
