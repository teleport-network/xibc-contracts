// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../../libraries/utils/Bytes.sol";
import "../../libraries/utils/Strings.sol";
import "../../interfaces/IClientManager.sol";
import "../../interfaces/IPacket.sol";
import "../../libraries/app/MultiCall.sol";
import "../../libraries/app/Transfer.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

contract Proxy is Initializable {
    using Strings for *;
    using Bytes for *;

    IClientManager public clientManager;
    IPacket public packet;

    function initialize(address clientManagerContract, address packetContract)
        public
        initializer
    {
        clientManager = IClientManager(clientManagerContract);
        packet = IPacket(packetContract);
    }

    function send(
        address refundAddressOnTeleport,
        string memory destChain,
        MultiCallDataTypes.TransferData memory erc20transfer,
        TransferDataTypes.TransferData memory rccTransfer,
        uint256 feeAmount
    ) public view returns (MultiCallDataTypes.MultiCallData memory) {
        bytes memory id = _getID(destChain);

        uint8[] memory functions = new uint8[](2);
        functions[0] = 0;
        functions[1] = 1;

        bytes[] memory dataList = new bytes[](2);
        dataList[0] = abi.encode(
            MultiCallDataTypes.TransferData({
                tokenAddress: erc20transfer.tokenAddress,
                receiver: erc20transfer.receiver,
                amount: erc20transfer.amount
            })
        );
        dataList[1] = _getRCCDataABI(
            id,
            refundAddressOnTeleport,
            erc20transfer.receiver,
            rccTransfer,
            feeAmount
        );

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
        address refundAddressOnTeleport,
        string memory contractAddress,
        TransferDataTypes.TransferData memory rccTransfer,
        uint256 feeAmount
    ) private pure returns (bytes memory) {
        bytes memory agentSendData = abi.encodeWithSignature(
            "send(bytes,address,address,string,string,uint256)",
            id,
            rccTransfer.tokenAddress,
            refundAddressOnTeleport,
            rccTransfer.receiver,
            rccTransfer.destChain,
            feeAmount
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
