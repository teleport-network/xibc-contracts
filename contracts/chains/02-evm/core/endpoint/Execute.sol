// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import "../../../../libraries/packet/Packet.sol";
import "../../../../libraries/utils/Bytes.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Execute is Initializable {
    using Bytes for *;

    address public packetContractAddress;

    // only xibc packet contract can perform related transactions
    modifier onlyPacket() {
        require(msg.sender == packetContractAddress, "caller must be Packet contract");
        _;
    }

    /**
     * @notice initialize contract address
     * @param _packetContractAddress packet contract address
     */
    function initialize(address _packetContractAddress) public initializer {
        packetContractAddress = _packetContractAddress;
    }

    /**
     * @notice execute call data
     */
    function execute(PacketTypes.CallData calldata callData) external returns (bool success, bytes memory res) {
        return callData.contractAddress.parseAddr().call(callData.callData);
    }
}
