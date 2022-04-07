// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "./IModule.sol";
import "../libraries/app/Transfer.sol";
import "../libraries/packet/Packet.sol";

interface ITransfer is IModule {
    function sendTransfer(
        TransferDataTypes.TransferData calldata transferData,
        PacketTypes.Fee calldata fee
    ) external payable;

    function transfer(TransferDataTypes.TransferDataMulti calldata transferData)
        external
        payable
        returns (bytes memory);

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
        returns (TransferDataTypes.TransferPacketData memory);
}
