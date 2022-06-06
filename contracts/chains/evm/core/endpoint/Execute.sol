// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../../../../libraries/packet/Packet.sol";
import "../../../../libraries/utils/Bytes.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

contract Execute is Initializable {
    using Bytes for *;

    address public packetContractAddress;

    modifier onlyPacket() {
        require(msg.sender == packetContractAddress, "caller must be Packet contract");
        _;
    }

    /**
     * @notice todo
     */
    function initialize(address _packetContractAddress) public initializer {
        packetContractAddress = _packetContractAddress;
    }

    /**
     * @notice todo
     */
    function execute(PacketTypes.CallData calldata callData) external returns (bool success, bytes memory res) {
        return callData.contractAddress.parseAddr().call(callData.callData);
    }
}
