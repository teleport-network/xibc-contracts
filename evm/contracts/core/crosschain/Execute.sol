// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../../interfaces/IExecute.sol";
import "../../libraries/utils/Bytes.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

contract Execute is Initializable, IExecute {
    using Bytes for *;

    address public crossChainContractAddress;

    modifier onlyCrossChain() {
        require(msg.sender == crossChainContractAddress, "caller must be CrossChain contract");
        _;
    }

    /**
     * @notice todo
     */
    function initialize(address _crossChainContractAddress) public initializer {
        crossChainContractAddress = _crossChainContractAddress;
    }

    /**
     * @notice todo
     */
    function execute(PacketTypes.CallData calldata callData)
        external
        override
        returns (bool success, bytes memory res)
    {
        return callData.contractAddress.parseAddr().call(callData.callData);
    }
}
