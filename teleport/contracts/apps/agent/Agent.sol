// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../../libraries/utils/Bytes.sol";
import "../../libraries/utils/Strings.sol";
import "../../interfaces/ICrossChain.sol";
import "../../interfaces/IPacket.sol";
import "../../interfaces/ICallback.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract Agent is ICallback, ReentrancyGuardUpgradeable {
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

    IPacket public constant packetContract = IPacket(0x0000000000000000000000000000000020000001);
    ICrossChain public constant crossChainContract = ICrossChain(0x0000000000000000000000000000000020000002);

    modifier onlyCrossChain() {
        require(msg.sender == address(crossChainContract), "caller must be XIBC CrossChain contract");
        _;
    }

    /**
     * @notice todo
     */
    function send(
        address tokenAddress,
        address refundAddressOnTeleport,
        string memory receiver,
        string memory destChain,
        uint256 feeAmount // precision should be same as srcChain
    ) public nonReentrant onlyCrossChain returns (bool) {
        /** Fake code*/
        /**
        if (token_bound) {
            scale_src = transfer.get_scale(token_src);
            scale_dest = transfer.get_scale(token_dest);

            real_amount_recv = amount * 10**uint256(scale_src);
            real_fee_amount = feeAmount * 10**uint256(scale_src);

            real_amount_available = real_amount_recv - real_fee_amount;              // store in AgentData
            real_amount_send = real_amount_available / 10**uint256(scale_dest);      // maybe loss of precision
        }
        */

        require(!destChain.equals(packetContract.chainName()), "invalid destChain");

        (
            uint256 msgValue,
            uint256 realFeeAmount,
            uint256 realAmountAvailable,
            uint256 realAmountSend
        ) = checkPacketSyncAndGetAmountSrcChain(tokenAddress, destChain, feeAmount);

        crossChainContract.crossChainCall{value: msgValue}(
            CrossChainDataTypes.CrossChainData({
                destChain: destChain,
                tokenAddress: tokenAddress,
                receiver: receiver,
                amount: realAmountSend,
                contractAddress: "",
                callData: "",
                callbackAddress: address(this),
                feeOption: 0 // TDB
            }),
            PacketTypes.Fee({tokenAddress: tokenAddress, amount: realFeeAmount})
        );

        uint64 sequence = packetContract.getNextSequenceSend(packetContract.chainName(), destChain);
        string memory sequencesKey = Strings.strConcat(Strings.strConcat(destChain, "/"), Strings.uint642str(sequence));

        agentData[sequencesKey] = AgentData({
            sent: true,
            refundAddressOnTeleport: refundAddressOnTeleport,
            tokenAddress: tokenAddress,
            amount: realAmountAvailable
        });

        return true;
    }

    /**
     * @notice todo
     */
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
        PacketTypes.Packet memory packet = packetContract.getLatestPacket();
        PacketTypes.TransferData memory transferData = abi.decode(packet.transferData, (PacketTypes.TransferData));

        require(transferData.receiver.equals(address(this).addressToString()), "must synchronize");

        IERC20 token = IERC20(tokenAddress);
        if (bytes(transferData.oriToken).length != 0) {
            require(transferData.oriToken.equals(tokenAddress.addressToString()), "invalid token address");
            uint256 amount = transferData.amount.toUint256();
            if (tokenAddress != address(0)) {
                token.approve(address(crossChainContract), amount);
                return (0, feeAmount, amount - feeAmount, amount - feeAmount);
            }
            return (amount, feeAmount, amount - feeAmount, amount - feeAmount);
        }

        address tokenAddressOnTeleport = crossChainContract.bindingTraces(
            Strings.strConcat(Strings.strConcat(packet.srcChain, "/"), transferData.token)
        );

        require(tokenAddressOnTeleport == tokenAddress, "invalid token address");

        string memory bindingKeySrc = Strings.strConcat(
            Strings.strConcat(tokenAddress.addressToString(), "/"),
            packet.srcChain
        );
        string memory bindingKeyDest = Strings.strConcat(
            Strings.strConcat(tokenAddress.addressToString(), "/"),
            destChain
        );

        uint256 scaleSrc = crossChainContract.getBindings(bindingKeySrc).scale;
        uint256 scaleDest = crossChainContract.getBindings(bindingKeyDest).scale; // will be 0 if not bound

        uint256 realAmountRecv = transferData.amount.toUint256() * 10**uint256(scaleSrc);
        uint256 realFeeAmount = feeAmount * 10**uint256(scaleSrc);

        uint256 realAmountAvailable = realAmountRecv - realFeeAmount;
        uint256 realAmountSend = realAmountAvailable / 10**uint256(scaleDest);

        token.approve(address(crossChainContract), realAmountRecv);

        return (0, realFeeAmount, realAmountAvailable, realAmountSend);
    }

    /**
     * @notice todo
     */
    function callback(
        string calldata,
        string calldata destChain,
        uint64 sequence,
        uint64 code,
        bytes calldata,
        string calldata
    ) external override onlyCrossChain {
        if (code != 0) {
            require(packetContract.getAckStatus(packetContract.chainName(), destChain, sequence) == 2, "not err ack");
            string memory sequencesKey = Strings.strConcat(
                Strings.strConcat(destChain, "/"),
                Strings.uint642str(sequence)
            );
            require(agentData[sequencesKey].sent, "not exist");

            AgentData memory data = agentData[sequencesKey];
            delete agentData[sequencesKey];

            if (data.tokenAddress == address(0)) {
                payable(data.refundAddressOnTeleport).transfer(data.amount);
                return;
            }

            require(
                IERC20(data.tokenAddress).transfer(data.refundAddressOnTeleport, data.amount),
                "refund failed, ERC20 transfer err"
            );
        }
    }
}
