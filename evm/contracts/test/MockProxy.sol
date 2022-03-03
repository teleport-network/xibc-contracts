// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../libraries/utils/Bytes.sol";
import "../libraries/utils/Strings.sol";
import "../interfaces/IMultiCall.sol";
import "../interfaces/IClientManager.sol";
import "../interfaces/ITransfer.sol";
import "../interfaces/IPacket.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MockProxy is Initializable, OwnableUpgradeable {
    using Strings for *;
    using Bytes for *;

    IClientManager public clientManager;
    IMultiCall public multiCall;
    IPacket public packet;
    ITransfer public transfer;

    function getVersion() public pure returns (uint64) {
        return 2;
    }

    function initialize(
        address clientMgrContract,
        address multiCallContract,
        address packetContract,
        address transferContract
    ) public initializer {
        multiCall = IMultiCall(multiCallContract);
        packet = IPacket(packetContract);
        clientManager = IClientManager(clientMgrContract);
        transfer = ITransfer(transferContract);
    }

    event SendEvent(
        bytes id,
        string srcChain,
        string destChain,
        uint256 sequence
    );

    function send(
        address refunder,
        string memory contractAddress,
        string memory destChain,
        MultiCallDataTypes.ERC20TransferData memory erc20transfer,
        TransferDataTypes.ERC20TransferData memory rccTransfer
    ) public view returns (MultiCallDataTypes.MultiCallData memory) {
        bytes memory id = _getID(destChain);
        bytes[] memory dataList = new bytes[](2);
        uint8[] memory functions = new uint8[](2);
        bytes memory RCCDataAbi = _getRCCDataABI(
            id,
            refunder,
            contractAddress,
            rccTransfer
        );

        require(
            erc20transfer.amount == rccTransfer.amount,
            "amount must be equal to rcc amount"
        );

        if (erc20transfer.tokenAddress != address(0)) {
            // send erc20
            bytes memory ERC20TransferDataAbi = abi.encode(
                MultiCallDataTypes.ERC20TransferData({
                    tokenAddress: erc20transfer.tokenAddress,
                    receiver: erc20transfer.receiver,
                    amount: erc20transfer.amount
                })
            );
            dataList[0] = ERC20TransferDataAbi;
            functions[0] = 0;
        } else {
            // send native token
            bytes memory BaseTransferDataAbi = abi.encode(
                MultiCallDataTypes.BaseTransferData({
                    receiver: erc20transfer.receiver,
                    amount: erc20transfer.amount
                })
            );
            dataList[0] = BaseTransferDataAbi;
            functions[0] = 1;
        }
        dataList[1] = RCCDataAbi;
        functions[1] = 2;

        MultiCallDataTypes.MultiCallData
            memory multiCallData = MultiCallDataTypes.MultiCallData({
                destChain: destChain,
                relayChain: "",
                functions: functions,
                data: dataList
            });

        return multiCallData;
    }

    function _getID(string memory destChain)
        private
        view
        returns (bytes memory)
    {
        string memory sourceChain = clientManager.getChainName();
        uint64 sequence = packet.getNextSequenceSend(sourceChain, destChain);

        bytes memory idKey = bytes(
            Strings.strConcat(
                Strings.strConcat(
                    Strings.strConcat(
                        Strings.strConcat(sourceChain, "/"),
                        destChain
                    ),
                    "/"
                ),
                Strings.uint642str(sequence)
            )
        );
        bytes memory id = Bytes.fromBytes32(sha256(idKey));
        return id;
    }

    function _getRCCDataABI(
        bytes memory id,
        address refunder,
        string memory contractAddress,
        TransferDataTypes.ERC20TransferData memory rccTransfer
    ) private pure returns (bytes memory) {
        bytes memory agentSendData = abi.encodeWithSignature(
            "send(bytes,address,address,string,uint256,string,string)",
            id,
            rccTransfer.tokenAddress,
            refunder,
            rccTransfer.receiver,
            rccTransfer.amount,
            rccTransfer.destChain,
            rccTransfer.relayChain
        );

        return
            abi.encode(
                MultiCallDataTypes.RCCData({
                    contractAddress: contractAddress,
                    data: agentSendData
                })
            );
    }
}
