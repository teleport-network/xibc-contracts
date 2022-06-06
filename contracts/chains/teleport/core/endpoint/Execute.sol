// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../../../../libraries/packet/Packet.sol";
import "../../../../libraries/utils/Bytes.sol";

contract Execute {
    using Bytes for *;

    address public constant packetContractAddress = address(0x0000000000000000000000000000000020000001);

    modifier onlyPacket() {
        require(msg.sender == packetContractAddress, "caller must be Packet contract");
        _;
    }

    /**
     * @notice todo
     */
    function execute(PacketTypes.CallData calldata callData) external returns (bool success, bytes memory res) {
        return callData.contractAddress.parseAddr().call(callData.callData);
    }
}