// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "./IModule.sol";
import "../libraries/app/RCC.sol";
import "../proto/RemoteContractCall.sol";

interface IRCC is IModule {
    function sendRemoteContractCall(RCCDataTypes.RCCData calldata rccData)
        external;

    function remoteContractCall(RCCDataTypes.RCCDataMulti calldata rccData)
        external
        returns (bytes memory);

    function acks(bytes32) external pure returns (bytes memory);

    function getLatestPacket()
        external
        view
        returns (RemoteContractCall.Data memory);
}
