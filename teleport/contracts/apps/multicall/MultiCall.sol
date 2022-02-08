// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../../libraries/utils/Bytes.sol";
import "../../libraries/utils/Strings.sol";
import "../../libraries/app/Transfer.sol";
import "../../libraries/app/RCC.sol";
import "../../interfaces/IMultiCall.sol";
import "../../interfaces/ITransfer.sol";
import "../../interfaces/IRCC.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MultiCall is IMultiCall {
    using Strings for *;
    using Bytes for *;

    string private constant nativeChainName = "teleport";

    address public constant transferContractAddress =
        address(0x0000000000000000000000000000000010000003);

    address public constant rccContractAddress =
        address(0x0000000000000000000000000000000010000004);

    event SendPacket(
        address sender,
        MultiCallDataTypes.MultiCallData multiCallData
    );

    function multiCall(MultiCallDataTypes.MultiCallData calldata multiCallData)
        external
        payable
        override
    {
        require(
            multiCallData.functions.length > 0 &&
                multiCallData.data.length == multiCallData.functions.length,
            "invalid data length"
        );

        require(
            !nativeChainName.equals(multiCallData.destChain),
            "sourceChain can't equal to destChain"
        );

        uint256 remainingValue = msg.value;

        for (uint64 i = 0; i < multiCallData.functions.length; i++) {
            require(multiCallData.functions[i] < 3, "invalid function ID");
            if (multiCallData.functions[i] == 0) {
                MultiCallDataTypes.ERC20TransferData memory data = abi.decode(
                    multiCallData.data[i],
                    (MultiCallDataTypes.ERC20TransferData)
                );
                callTransferERC20(multiCallData.destChain, data);
            } else if (multiCallData.functions[i] == 1) {
                MultiCallDataTypes.BaseTransferData memory data = abi.decode(
                    multiCallData.data[i],
                    (MultiCallDataTypes.BaseTransferData)
                );
                require(data.amount > 0, "invalid amount");
                require(remainingValue >= data.amount, "invalid value");
                callTransferBase(multiCallData.destChain, data);
                remainingValue -= data.amount;
            } else {
                MultiCallDataTypes.RCCData memory data = abi.decode(
                    multiCallData.data[i],
                    (MultiCallDataTypes.RCCData)
                );
                require(
                    !data.contractAddress.equals(""),
                    "invalid ContractAddress"
                );
                callRCC(multiCallData.destChain, data);
            }
        }

        emit SendPacket(msg.sender, multiCallData);
    }

    function callTransferERC20(
        string memory destChain,
        MultiCallDataTypes.ERC20TransferData memory data
    ) internal {
        ITransfer(transferContractAddress).transferERC20(
            TransferDataTypes.ERC20TransferDataMulti({
                tokenAddress: data.tokenAddress,
                sender: msg.sender,
                receiver: data.receiver,
                amount: data.amount,
                destChain: destChain
            })
        );
    }

    function callTransferBase(
        string memory destChain,
        MultiCallDataTypes.BaseTransferData memory data
    ) internal {
        ITransfer(transferContractAddress).transferBase{value: data.amount}(
            TransferDataTypes.BaseTransferDataMulti({
                sender: msg.sender,
                receiver: data.receiver,
                destChain: destChain
            })
        );
    }

    function callRCC(
        string memory destChain,
        MultiCallDataTypes.RCCData memory data
    ) internal {
        IRCC(rccContractAddress).remoteContractCall(
            RCCDataTypes.RCCDataMulti({
                sender: msg.sender,
                contractAddress: data.contractAddress,
                data: data.data,
                destChain: destChain
            })
        );
    }
}
