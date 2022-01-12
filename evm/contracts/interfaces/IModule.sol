// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../libraries/packet/Packet.sol";

interface IModule {
    function onRecvPacket(bytes calldata data)
        external
        returns (PacketTypes.Result memory result);

    function onAcknowledgementPacket(bytes calldata data, bytes calldata result)
        external;
}
