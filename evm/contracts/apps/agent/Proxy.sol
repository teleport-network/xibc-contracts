// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../../libraries/utils/Bytes.sol";
import "../../libraries/utils/Strings.sol";
import "../../libraries/crosschain/CrossChain.sol";
import "../../libraries/packet/Packet.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

contract Proxy is Initializable {
    using Strings for *;
    using Bytes for *;

    address public constant agentContractAddress = address(0x0000000000000000000000000000000040000001);
    string public relayChainName;

    struct AgentData {
        address refundAddress; // refund address on relay chain
        string destChain; // dest chain, not relay chain
        address tokenAddress; // token on src chain
        uint256 amount;
        uint256 feeAmount;
        string receiver; // token on dest chain
        address callbackAddress;
        uint64 feeOption;
    }

    /**
     * @notice todo
     */
    function initialize(string memory _relayChainName) public initializer {
        require(!_relayChainName.equals(""), "invalid relay chain name");
        relayChainName = _relayChainName;
    }

    /**
     * @notice todo
     */
    function generateCrossChainData(AgentData memory agentData)
        public
        view
        returns (CrossChainDataTypes.CrossChainData memory)
    {
        return
            CrossChainDataTypes.CrossChainData({
                destChain: relayChainName,
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
        return
            abi.encodeWithSignature(
                "send(address,string,string,uint256)",
                agentData.refundAddress,
                agentData.receiver,
                agentData.destChain,
                agentData.feeAmount
            );
    }
}
