// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "./IModule.sol";
import "../../contracts/libraries/app/RCC.sol";

interface IRCC is IModule {
    function sendRemoteContractCall(RCCDataTypes.RCCData calldata rccData)
        external;

    function remoteContractCall(RCCDataTypes.RCCDataMulti calldata rccData)
        external
        returns (bytes memory);
}
