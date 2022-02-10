// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "./IModule.sol";
import "../libraries/app/Transfer.sol";

interface ITransfer is IModule {
    function sendTransferERC20(
        TransferDataTypes.ERC20TransferData calldata transferData
    ) external;

    function sendTransferBase(
        TransferDataTypes.BaseTransferData calldata transferData
    ) external payable;

    function transferERC20(
        TransferDataTypes.ERC20TransferDataMulti calldata transferData
    ) external returns (bytes memory);

    function transferBase(
        TransferDataTypes.BaseTransferDataMulti calldata transferData
    ) external payable returns (bytes memory);

    function boundTokens(uint256) external pure returns (address);

    function bindingTraces(string calldata) external pure returns (address);

    function outTokens(address, string calldata)
        external
        pure
        returns (uint256);

    function getBindings(address)
        external
        view
        returns (TransferDataTypes.InToken memory);

    function getLatestPacket()
        external
        view
        returns (TransferDataTypes.TokenTransfer memory);
}
