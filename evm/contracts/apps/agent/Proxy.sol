// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../../libraries/utils/Bytes.sol";
import "../../libraries/crosschain/CrossChain.sol";
import "../../libraries/packet/Packet.sol";

contract Proxy {
    using Bytes for *;

    address public constant agentContractAddress = address(0x0000000000000000000000000000000040000001);

    struct AgentData {
        address refundAddressOnTeleport;
        string destChain;
        string receiver;
        uint256 amount;
        address tokenAddress;
        string oriToken;
        uint256 feeAmount;
        address callbackAddress;
        uint64 feeOption;
    }

    /**
     * @notice todo
     */
    function generateCrossChainData(AgentData memory agentData)
        public
        pure
        returns (CrossChainDataTypes.CrossChainData memory)
    {
        return
            CrossChainDataTypes.CrossChainData({
                destChain: agentData.destChain,
                tokenAddress: agentData.tokenAddress,
                receiver: agentData.receiver,
                amount: agentData.amount,
                contractAddress: agentContractAddress.addressToString(),
                callData: _generateCalldata(agentData),
                callbackAddress: agentData.callbackAddress,
                feeOption: agentData.feeOption
            });
    }

    /**
     * @notice todo
     */
    function _generateCalldata(AgentData memory agentData) private pure returns (bytes memory) {
        bytes memory agentSendData = abi.encodeWithSignature(
            "send(address,address,string,string,uint256)",
            agentData.tokenAddress,
            agentData.refundAddressOnTeleport,
            agentData.receiver,
            agentData.destChain,
            agentData.feeAmount
        );

        return
            abi.encode(
                PacketTypes.CallData({contractAddress: agentContractAddress.addressToString(), callData: agentSendData})
            );
    }
}
