// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../../libraries/utils/Bytes.sol";
import "../../libraries/utils/Strings.sol";
import "../../libraries/app/Transfer.sol";
import "../../libraries/app/RCC.sol";
import "../../libraries/core/Packet.sol";
import "../../interfaces/IMultiCall.sol";
import "../../interfaces/ITransfer.sol";
import "../../interfaces/IRCC.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MultiCall is IMultiCall {
    using Strings for *;
    using Bytes for *;

    string private constant nativeChainName = "teleport";

    address public constant transferContractAddress =
        address(0x0000000000000000000000000000000030000001);
    address public constant rccContractAddress =
        address(0x0000000000000000000000000000000030000002);

    event SendPacket(
        address sender,
        MultiCallDataTypes.MultiCallData multiCallData
    );

    function multiCall(
        MultiCallDataTypes.MultiCallData memory multiCallData,
        PacketTypes.Fee memory fee
    ) public payable override {
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

        if (fee.tokenAddress == address(0)) {
            require(msg.value > fee.amount, "insufficient amount");
            remainingValue = remainingValue - fee.amount;
        }

        for (uint64 i = 0; i < multiCallData.functions.length; i++) {
            require(multiCallData.functions[i] < 2, "invalid function ID");
            if (multiCallData.functions[i] == 0) {
                MultiCallDataTypes.TransferData memory data = abi.decode(
                    multiCallData.data[i],
                    (MultiCallDataTypes.TransferData)
                );
                require(data.amount > 0, "invalid amount");
                if (data.tokenAddress == address(0)) {
                    require(remainingValue >= data.amount, "invalid value");
                    remainingValue -= data.amount;
                }
                callTransfer(multiCallData.destChain, data);
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

    function callTransfer(
        string memory destChain,
        MultiCallDataTypes.TransferData memory data
    ) internal {
        if (data.tokenAddress == address(0)) {
            ITransfer(transferContractAddress).transfer{value: data.amount}(
                TransferDataTypes.TransferDataMulti({
                    tokenAddress: data.tokenAddress,
                    sender: msg.sender,
                    receiver: data.receiver,
                    amount: data.amount,
                    destChain: destChain
                })
            );
        } else {
            ITransfer(transferContractAddress).transfer(
                TransferDataTypes.TransferDataMulti({
                    tokenAddress: data.tokenAddress,
                    sender: msg.sender,
                    receiver: data.receiver,
                    amount: data.amount,
                    destChain: destChain
                })
            );
        }
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
