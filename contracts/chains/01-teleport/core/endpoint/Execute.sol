// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import "../../../../libraries/packet/Packet.sol";
import "../../../../libraries/utils/Bytes.sol";

contract Execute {
    using Bytes for *;

    address public constant packetContractAddress = address(0x0000000000000000000000000000000020000001);

    // only xibc packet contract can perform related transactions
    modifier onlyPacket() {
        require(msg.sender == packetContractAddress, "caller must be Packet contract");
        _;
    }

    /**
     * @notice execute call data
     */
    function execute(PacketTypes.CallData calldata callData) external returns (bool success, bytes memory res) {
        return callData.contractAddress.parseAddr().call(callData.callData);
    }
}
