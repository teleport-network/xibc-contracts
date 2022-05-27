// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../libraries/packet/Packet.sol";

interface IExecute {
    /**
     * @notice todo
     */
    function execute(PacketTypes.CallData calldata callData) external returns (bool success, bytes memory res);
}
