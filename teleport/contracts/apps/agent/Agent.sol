// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../../libraries/utils/Bytes.sol";
import "../../libraries/utils/Strings.sol";
import "../../interfaces/IEndpoint.sol";
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
        address tokenAddress;
        uint256 amount;
        address refundAddress; // refund address on relay chain
    }

    mapping(string => AgentData) public agentData; // map[dstChain/sequence]AgentData

    IPacket public constant packetContract = IPacket(0x0000000000000000000000000000000020000001);
    IEndpoint public constant endpointContract = IEndpoint(0x0000000000000000000000000000000020000002);
    address public constant executeContract = address(0x0000000000000000000000000000000020000003);

    /**
     * @notice todo
     */
    modifier onlyCrossChain() {
        require(msg.sender == address(endpointContract), "caller must be Endpoint contract");
        _;
    }

    /**
     * @notice todo
     */
    modifier onlyExecute() {
        require(msg.sender == executeContract, "caller must be Execute contract");
        _;
    }

    /**
     * @notice todo
     */
    function send(
        address refundAddress, // refund address on relay chain
        string memory receiver,
        string memory dstChain,
        uint256 feeAmount // precision should be same as srcChain
    ) public nonReentrant onlyExecute returns (bool) {
        /** Fake code
        if (token_bound) {
            scale_src = transfer.get_scale(token_src);
            scale_dst = transfer.get_scale(token_dst);

            real_amount_recv = amount * 10**uint256(scale_src);
            real_fee_amount = feeAmount * 10**uint256(scale_src);

            real_amount_available = real_amount_recv - real_fee_amount;              // store in AgentData
            real_amount_send = real_amount_available / 10**uint256(scale_dst);      // maybe loss of precision
        }
        */

        require(!dstChain.equals(packetContract.chainName()), "invalid dstChain");

        (
            address tokenAddress,
            uint256 msgValue,
            uint256 realFeeAmount,
            uint256 realAmountAvailable,
            uint256 realAmountSend
        ) = checkPacketSyncAndGetAmountSrcChain(dstChain, feeAmount);

        endpointContract.crossChainCall{value: msgValue}(
            CrossChainDataTypes.CrossChainData({
                dstChain: dstChain,
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

        uint64 sequence = packetContract.getNextSequenceSend(dstChain);
        string memory sequencesKey = Strings.strConcat(Strings.strConcat(dstChain, "/"), Strings.uint642str(sequence));

        agentData[sequencesKey] = AgentData({
            sent: true,
            tokenAddress: tokenAddress,
            amount: realAmountAvailable,
            refundAddress: refundAddress
        });

        return true;
    }

    /**
     * @notice todo
     */
    function checkPacketSyncAndGetAmountSrcChain(string memory dstChain, uint256 feeAmount)
        private
        returns (
            address, // tokenAddress
            uint256, // msgValue
            uint256, // realFeeAmount
            uint256, // realAmountAvailable
            uint256 // realAmountSend
        )
    {
        PacketTypes.Packet memory packet = packetContract.getLatestPacket();
        PacketTypes.TransferData memory transferData = abi.decode(packet.transferData, (PacketTypes.TransferData));
        require(transferData.receiver.equals(address(this).addressToString()), "token receiver must be agent contract");

        address tokenAddress;
        // true: back to origin. false: token come in
        if (bytes(transferData.oriToken).length != 0) {
            tokenAddress = transferData.oriToken.parseAddr();
            uint256 amount = transferData.amount.toUint256();
            // true: base token. false: erc20 token
            if (tokenAddress == address(0)) {
                return (address(0), amount, feeAmount, amount - feeAmount, amount - feeAmount);
            }
            IERC20(tokenAddress).approve(address(endpointContract), amount);
            return (tokenAddress, 0, feeAmount, amount - feeAmount, amount - feeAmount);
        }
        tokenAddress = endpointContract.bindingTraces(
            Strings.strConcat(Strings.strConcat(packet.srcChain, "/"), transferData.token)
        );

        uint256 scaleSrc = endpointContract
            .getBindings(Strings.strConcat(Strings.strConcat(tokenAddress.addressToString(), "/"), packet.srcChain))
            .scale;
        uint256 scaleDst = endpointContract
            .getBindings(Strings.strConcat(Strings.strConcat(tokenAddress.addressToString(), "/"), dstChain))
            .scale; // will be 0 if not bound

        uint256 realAmountRecv = transferData.amount.toUint256() * 10**uint256(scaleSrc);
        uint256 realFeeAmount = feeAmount * 10**uint256(scaleSrc);
        uint256 realAmountAvailable = realAmountRecv - realFeeAmount;
        uint256 realAmountSend = realAmountAvailable / 10**uint256(scaleDst);

        IERC20(tokenAddress).approve(address(endpointContract), realAmountRecv);

        return (tokenAddress, 0, realFeeAmount, realAmountAvailable, realAmountSend);
    }

    /**
     * @notice todo
     */
    function callback(
        string calldata,
        string calldata dstChain,
        uint64 sequence,
        uint64 code,
        bytes calldata,
        string calldata
    ) external override onlyCrossChain {
        if (code != 0) {
            require(packetContract.getAckStatus(dstChain, sequence) == 2, "not err ack");
            string memory sequencesKey = Strings.strConcat(
                Strings.strConcat(dstChain, "/"),
                Strings.uint642str(sequence)
            );
            require(agentData[sequencesKey].sent, "not exist");

            AgentData memory data = agentData[sequencesKey];
            delete agentData[sequencesKey];

            if (data.tokenAddress == address(0)) {
                payable(data.refundAddress).transfer(data.amount);
                return;
            }

            require(
                IERC20(data.tokenAddress).transfer(data.refundAddress, data.amount),
                "refund failed, ERC20 transfer err"
            );
        }
    }
}
