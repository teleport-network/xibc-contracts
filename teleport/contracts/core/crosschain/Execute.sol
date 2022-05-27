// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../../interfaces/IExecute.sol";
import "../../libraries/utils/Bytes.sol";

contract Execute is IExecute {
    using Bytes for *;

    address public constant crossChainContractAddress = address(0x0000000000000000000000000000000020000002);

    modifier onlyCrossChain() {
        require(msg.sender == crossChainContractAddress, "caller must be CrossChain contract");
        _;
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
