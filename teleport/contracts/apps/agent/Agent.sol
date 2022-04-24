// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../../libraries/utils/Bytes.sol";
import "../../libraries/utils/Strings.sol";
import "../../libraries/core/Packet.sol";
import "../../libraries/app/Transfer.sol";
import "../../libraries/app/RCC.sol";
import "../../interfaces/IMultiCall.sol";
import "../../interfaces/ITransfer.sol";
import "../../interfaces/IRCC.sol";
import "../../interfaces/IPacket.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract Agent is ReentrancyGuardUpgradeable {
    receive() external payable {}

    using Strings for *;
    using Bytes for *;

    struct AgentData {
        bool sent;
        address refundAddressOnTeleport;
        address tokenAddress;
        uint256 amount;
    }

    mapping(string => AgentData) public agentData; // map[destChain/sequence]AgentData

    IPacket packetContract =
        IPacket(address(0x0000000000000000000000000000000020000001));
    ITransfer transferContract =
        ITransfer(address(0x0000000000000000000000000000000030000001));
    IRCC rccContract =
        IRCC(address(0x0000000000000000000000000000000030000002));

    modifier onlyRCCContract() {
        require(
            msg.sender == address(rccContract),
            "caller must be XIBC RCC module"
        );
        _;
    }

    event SendEvent(bytes id, string destChain, uint256 sequence);

    function send(
        bytes memory id,
        address tokenAddress,
        address refundAddressOnTeleport,
        string memory receiver,
        string memory destChain,
        uint256 feeAmount // precision should be same as srcChain
    ) public nonReentrant onlyRCCContract returns (bool) {
        /** Fake code*/
        /**
        if (token_bound) {
            scale_src = transfer.get_scale(token_src);
            scale_dest = transfer.get_scale(token_dest);

            real_amount_recv = amount * 10**uint256(scale_src);
            real_fee_amount = feeAmount * 10**uint256(scale_src);

            real_amount_available = real_amount_recv - real_fee_amount;                             // store in AgentData
            real_amount_send = real_amount_available / 10**uint256(scale_dest);      // maybe loss of precision
        }
        */

        (
            uint256 msgValue,
            uint256 realFeeAmount,
            uint256 realAmountAvailable,
            uint256 realAmountSend
        ) = checkPacketSyncAndGetAmountSrcChain(
                tokenAddress,
                destChain,
                feeAmount
            );

        transferContract.sendTransfer{value: msgValue}(
            TransferDataTypes.TransferData({
                tokenAddress: tokenAddress,
                receiver: receiver,
                amount: realAmountSend,
                destChain: destChain,
                relayChain: ""
            }),
            PacketTypes.Fee({tokenAddress: tokenAddress, amount: realFeeAmount})
        );

        uint64 sequence = packetContract.getNextSequenceSend(
            "teleport",
            destChain
        );
        string memory sequencesKey = Strings.strConcat(
            Strings.strConcat(destChain, "/"),
            Strings.uint642str(sequence)
        );

        agentData[sequencesKey] = AgentData({
            sent: true,
            refundAddressOnTeleport: refundAddressOnTeleport,
            tokenAddress: tokenAddress,
            amount: realAmountAvailable
        });

        emit SendEvent(id, destChain, sequence);
        return true;
    }

    function checkPacketSyncAndGetAmountSrcChain(
        address tokenAddress,
        string memory destChain,
        uint256 feeAmount
    )
        private
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        RCCDataTypes.PacketData memory rccPacket = rccContract
            .getLatestPacket();
        TransferDataTypes.PacketData memory transferPacket = transferContract
            .getLatestPacket();

        require(
            transferPacket.receiver.equals(address(this).addressToString()) &&
                transferPacket.sequence == rccPacket.sequence &&
                transferPacket.srcChain.equals(rccPacket.srcChain) &&
                transferPacket.destChain.equals("teleport") &&
                rccPacket.destChain.equals("teleport"),
            "must synchronize"
        );

        IERC20 token = IERC20(tokenAddress);

        if (bytes(transferPacket.oriToken).length != 0) {
            require(
                transferPacket.oriToken.equals(tokenAddress.addressToString()),
                "invalid token address"
            );
            uint256 amount = transferPacket.amount.toUint256();

            if (tokenAddress != address(0)) {
                token.approve(address(transferContract), amount - feeAmount);
                return (0, feeAmount, amount - feeAmount, amount - feeAmount);
            }

            return (amount, feeAmount, amount - feeAmount, amount - feeAmount);
        }

        address tokenAddressOnTeleport = transferContract.bindingTraces(
            Strings.strConcat(
                Strings.strConcat(transferPacket.srcChain, "/"),
                transferPacket.token
            )
        );

        require(
            tokenAddressOnTeleport == tokenAddress,
            "invalid token address"
        );

        string memory bindingKeySrc = Strings.strConcat(
            Strings.strConcat(tokenAddress.addressToString(), "/"),
            transferPacket.srcChain
        );

        string memory bindingKeyDest = Strings.strConcat(
            Strings.strConcat(tokenAddress.addressToString(), "/"),
            destChain
        );

        uint256 scaleSrc = transferContract.getBindings(bindingKeySrc).scale;
        uint256 scaleDest = transferContract.getBindings(bindingKeyDest).scale; // will be 0 if not bound

        uint256 realAmountRecv = transferPacket.amount.toUint256() *
            10**uint256(scaleSrc);
        uint256 realFeeAmount = feeAmount * 10**uint256(scaleSrc);

        uint256 realAmountAvailable = realAmountRecv - realFeeAmount;
        uint256 realAmountSend = realAmountAvailable / 10**uint256(scaleDest);

        token.approve(address(transferContract), realAmountAvailable);

        return (0, realFeeAmount, realAmountAvailable, realAmountSend);
    }

    function refund(string calldata destChain, uint64 sequence)
        external
        nonReentrant
    {
        string memory sequencesKey = Strings.strConcat(
            Strings.strConcat(destChain, "/"),
            Strings.uint642str(sequence)
        );

        require(agentData[sequencesKey].sent, "not exist");
        AgentData memory data = agentData[sequencesKey];
        delete agentData[sequencesKey];
        require(
            packetContract.getAckStatus("teleport", destChain, sequence) == 2,
            "not err ack"
        );

        if (data.tokenAddress == address(0)) {
            payable(data.refundAddressOnTeleport).transfer(data.amount);
            return;
        }

        require(
            IERC20(data.tokenAddress).transfer(
                data.refundAddressOnTeleport,
                data.amount
            ),
            "refund failed, ERC20 transfer err"
        );
    }
}
