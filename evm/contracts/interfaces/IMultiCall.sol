// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "./IModule.sol";
import "../libraries/packet/Packet.sol";
import "../../contracts/libraries/app/MultiCall.sol";

interface IMultiCall {
    function multiCall(
        MultiCallDataTypes.MultiCallData calldata multiCallData,
        PacketTypes.Fee calldata fee
    ) external payable;
}
