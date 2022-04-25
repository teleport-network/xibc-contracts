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

contract MultiCall is Initializable, IMultiCall, OwnableUpgradeable {
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

    function multiCall(
        MultiCallDataTypes.MultiCallData memory multiCallData,
        PacketTypes.Fee memory fee
    ) public payable override {
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

        if (fee.tokenAddress == address(0)) {
            require(msg.value >= fee.amount, "insufficient amount");
            remainingValue = remainingValue - fee.amount;
        }

        for (uint64 i = 0; i < multiCallData.functions.length; i++) {
            require(multiCallData.functions[i] < 2, "invalid function ID");
            if (multiCallData.functions[i] == 0) {
                MultiCallDataTypes.TransferData memory data = abi.decode(
                    multiCallData.data[i],
                    (MultiCallDataTypes.TransferData)
                );
                if (data.tokenAddress == address(0)) {
                    require(remainingValue >= data.amount, "invalid value");
                    remainingValue -= data.amount;
                }
                dataList[i] = callTransfer(multiCallData.destChain, data);
                ports[i] = "FT";
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

        if (fee.tokenAddress == address(0)) {
            packet.sendMultiPacket{value: fee.amount}(crossPacket, fee);
        } else {
            require(
                IERC20(fee.tokenAddress).transferFrom(
                    msg.sender,
                    address(packet),
                    fee.amount
                ),
                "ERC20 fee: insufficient allowance"
            );
            packet.sendMultiPacket(crossPacket, fee);
        }
    }

    function callTransfer(
        string memory destChain,
        MultiCallDataTypes.TransferData memory data
    ) internal returns (bytes memory) {
        if (data.tokenAddress == address(0)) {
            return
                transfer.transfer{value: data.amount}(
                    TransferDataTypes.TransferDataMulti({
                        tokenAddress: data.tokenAddress,
                        sender: msg.sender,
                        receiver: data.receiver,
                        amount: data.amount,
                        destChain: destChain
                    })
                );
        } else {
            require(
                IERC20(data.tokenAddress).transferFrom(
                    msg.sender,
                    address(this),
                    data.amount
                ),
                "ERC20: insufficient allowance"
            );
            require(
                IERC20(data.tokenAddress).approve(
                    address(transfer),
                    data.amount
                ),
                "ERC20: approve failed"
            );
            return
                transfer.transfer(
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
