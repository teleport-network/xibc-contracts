// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../../libraries/utils/Bytes.sol";
import "../../libraries/utils/Strings.sol";
import "../../libraries/app/RCC.sol";
import "../../libraries/app/Transfer.sol";
import "../../libraries/app/RCC.sol";
import "../../libraries/packet/Packet.sol";
import "../../interfaces/IMultiCall.sol";
import "../../interfaces/IClientManager.sol";
import "../../interfaces/IRCC.sol";
import "../../interfaces/ITransfer.sol";
import "../../interfaces/IPacket.sol";
import "../../interfaces/IAccessManager.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract MultiCall is Initializable, IMultiCall, OwnableUpgradeable ,ReentrancyGuard{
    using Strings for *;
    using Bytes for *;

    IPacket public packet;
    IClientManager public clientManager;
    ITransfer public transfer;
    IRCC public rcc;

    function initialize(
        address packetContract,
        address clientMgrContract,
        address transferContract,
        address rccContract
    ) public initializer {
        packet = IPacket(packetContract);
        clientManager = IClientManager(clientMgrContract);
        transfer = ITransfer(transferContract);
        rcc = IRCC(rccContract);
    }

    function multiCall(MultiCallDataTypes.MultiCallData calldata multiCallData)
        external
        payable
        override
        nonReentrant
    {
        require(
            multiCallData.functions.length > 0 &&
                multiCallData.data.length == multiCallData.functions.length,
            "invalid data length"
        );

        string memory sourceChain = clientManager.getChainName();
        require(
            !sourceChain.equals(multiCallData.destChain),
            "sourceChain can't equal to destChain"
        );

        // send packet
        string[] memory ports = new string[](multiCallData.functions.length);
        bytes[] memory dataList = new bytes[](multiCallData.functions.length);

        uint256 remainingValue = msg.value;
        for (uint64 i = 0; i < multiCallData.functions.length; i++) {
            require(multiCallData.functions[i] < 3, "invlaid function ID");
            if (multiCallData.functions[i] == 0) {
                MultiCallDataTypes.ERC20TransferData memory data = abi.decode(
                    multiCallData.data[i],
                    (MultiCallDataTypes.ERC20TransferData)
                );
                dataList[i] = callTransferERC20(multiCallData.destChain, data);
                ports[i] = "FT";
            } else if (multiCallData.functions[i] == 1) {
                MultiCallDataTypes.BaseTransferData memory data = abi.decode(
                    multiCallData.data[i],
                    (MultiCallDataTypes.BaseTransferData)
                );
                require(data.amount > 0, "invalid amount");
                require(remainingValue >= data.amount, "invalid value");
                dataList[i] = callTransferBase(multiCallData.destChain, data);
                ports[i] = "FT";
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
                dataList[i] = callRCC(multiCallData.destChain, data);
                ports[i] = "CONTRACT";
            }
        }

        PacketTypes.Packet memory crossPacket = PacketTypes.Packet({
            sequence: packet.getNextSequenceSend(
                sourceChain,
                multiCallData.destChain
            ),
            sourceChain: sourceChain,
            destChain: multiCallData.destChain,
            relayChain: multiCallData.relayChain,
            ports: ports,
            dataList: dataList
        });
        packet.sendMultiPacket(crossPacket);
    }

    function callTransferERC20(
        string memory destChain,
        MultiCallDataTypes.ERC20TransferData memory data
    ) internal returns (bytes memory) {
        return
            transfer.transferERC20(
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
    ) internal returns (bytes memory) {
        return
            transfer.transferBase{value: data.amount}(
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
    ) internal returns (bytes memory) {
        return
            rcc.remoteContractCall(
                RCCDataTypes.RCCDataMulti({
                    sender: msg.sender,
                    contractAddress: data.contractAddress,
                    data: data.data,
                    destChain: destChain
                })
            );
    }
}
