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

    mapping(string => AgentData) public agentData; // map[srcChain/destChain/sequence]AgentData

    address public constant packetContractAddress =
        address(0x0000000000000000000000000000000020000001);
    address public constant transferContractAddress =
        address(0x0000000000000000000000000000000030000001);
    address public constant rccContractAddress =
        address(0x0000000000000000000000000000000030000002);

    modifier onlyXIBCModuleRCC() {
        require(
            msg.sender == rccContractAddress,
            "caller must be XIBC RCC module"
        );
        _;
    }

    event SendEvent(
        bytes id,
        string srcChain,
        string destChain,
        uint256 sequence
    );

    function send(
        bytes calldata id,
        address tokenAddress,
        address refundAddressOnTeleport,
        string calldata receiver,
        string calldata destChain,
        string calldata relayChain
    ) external nonReentrant onlyXIBCModuleRCC returns (bool) {
        (
            uint256 amount,
            string memory srcChain
        ) = checkPacketSyncAndGetAmountSrcChain();

        if (tokenAddress != address(0)) {
            IERC20(tokenAddress).approve(
                address(transferContractAddress),
                amount
            );
            // call transfer to send erc20
            ITransfer(transferContractAddress).sendTransferERC20(
                TransferDataTypes.ERC20TransferData({
                    tokenAddress: tokenAddress,
                    receiver: receiver,
                    amount: amount,
                    destChain: destChain,
                    relayChain: relayChain
                })
            );
        } else {
            // call transfer to send base
            ITransfer(transferContractAddress).sendTransferBase{value: amount}(
                TransferDataTypes.BaseTransferData({
                    receiver: receiver,
                    destChain: destChain,
                    relayChain: relayChain
                })
            );
        }

        uint64 sequence = IPacket(packetContractAddress).getNextSequenceSend(
            srcChain,
            destChain
        );
        string memory sequencesKey = Strings.strConcat(
            Strings.strConcat(
                Strings.strConcat(Strings.strConcat(srcChain, "/"), destChain),
                "/"
            ),
            Strings.uint642str(sequence)
        );

        agentData[sequencesKey] = AgentData({
            sent: true,
            refundAddressOnTeleport: refundAddressOnTeleport,
            tokenAddress: tokenAddress,
            amount: amount
        });

        emit SendEvent(id, srcChain, destChain, sequence);
        return true;
    }

    function checkPacketSyncAndGetAmountSrcChain()
        private
        view
        returns (uint256, string memory)
    {
        RCCDataTypes.PacketData memory rccPacket = IRCC(rccContractAddress)
            .getLatestPacket();
        TransferDataTypes.PacketData memory transferPacket = ITransfer(
            transferContractAddress
        ).getLatestPacket();

        require(
            transferPacket.receiver.equals(address(this).addressToString()) &&
                transferPacket.sequence == rccPacket.sequence &&
                transferPacket.srcChain.equals(rccPacket.srcChain) &&
                transferPacket.destChain.equals(rccPacket.destChain),
            "must synchronize"
        );
        return (transferPacket.amount.toUint256(), transferPacket.destChain);
    }

    function refund(
        string calldata srcChain,
        string calldata destChain,
        uint64 sequence
    ) external nonReentrant {
        string memory sequencesKey = Strings.strConcat(
            Strings.strConcat(
                Strings.strConcat(Strings.strConcat(srcChain, "/"), destChain),
                "/"
            ),
            Strings.uint642str(sequence)
        );

        require(agentData[sequencesKey].sent, "not exist");
        AgentData memory data = agentData[sequencesKey];
        delete agentData[sequencesKey];
        require(
            IPacket(packetContractAddress).getAckStatus(
                srcChain,
                destChain,
                sequence
            ) == 2,
            "not err ack"
        );

        require(
            IERC20(data.tokenAddress).transfer(data.refundAddressOnTeleport, data.amount),
            "refund failed,ERC20 transfer err"
        );
    }
}
