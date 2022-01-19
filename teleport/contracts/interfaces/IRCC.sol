// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../libraries/core/Result.sol";
import "../libraries/app/RCC.sol";

interface IRCC {
    function sendRemoteContractCall(RCCDataTypes.RCCData calldata rccData)
        external;

    function remoteContractCall(RCCDataTypes.RCCDataMulti calldata rccData)
        external;

    function onRecvPacket(RCCDataTypes.PacketData calldata packet)
        external
        returns (Result.Data memory);

    function onAcknowledgementPacket(bytes32 dataHash, bytes calldata result)
        external;

    function acks(bytes32) external pure returns (bytes memory);

    function getLatestPacket()
        external
        view
        returns (RCCDataTypes.PacketData memory);
}
