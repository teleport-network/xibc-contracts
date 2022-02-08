// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../../libraries/utils/Bytes.sol";
import "../../libraries/utils/Strings.sol";
import "../../interfaces/IMultiCall.sol";
import "../../interfaces/ITransfer.sol";
import "../../interfaces/IRCC.sol";
import "../../interfaces/IPacket.sol";
import "../../proto/RemoteContractCall.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Agent is Initializable, OwnableUpgradeable {
    using Strings for *;
    using Bytes for *;

    struct AgentData {
        bool sent;
        string sender;
        address tokenAddress;
        uint256 amount;
    }

    ITransfer public transfer;
    IRCC public rcc;
    IPacket public packet;

    mapping(string => mapping(address => uint256)) public balances; // map[sender]map[token]amount
    mapping(address => uint256) public supplies; //map[token]amount
    mapping(string => AgentData) public sequences; //map[srcChain/destChain/sequence]transferPacketData
    mapping(string => bool) public refunded;

    modifier onlyXIBCModuleRCC() {
        require(msg.sender == address(rcc), "caller must be XIBC RCC Contract");
        _;
    }

    function initialize(
        address transferContract,
        address rccContract,
        address packetContract
    ) public initializer {
        transfer = ITransfer(transferContract);
        rcc = IRCC(rccContract);
        packet = IPacket(packetContract);
    }

    event SendEvent(
        bytes indexed id,
        string srcChain,
        string destChain,
        uint64 sequence
    );

    function send(
        bytes calldata id,
        address tokenAddress,
        string calldata receiver,
        uint256 amount,
        string calldata destChain,
        string calldata relayChain
    ) external onlyXIBCModuleRCC returns (bool) {
        TransferDataTypes.ERC20TransferData
            memory transferData = TransferDataTypes.ERC20TransferData({
                tokenAddress: tokenAddress,
                receiver: receiver,
                amount: amount,
                destChain: destChain,
                relayChain: relayChain
            });

        RemoteContractCall.Data memory rccPacket = rcc.getLatestPacket();

        _comingIn(rccPacket, transferData.tokenAddress);
        require(
            balances[rccPacket.sender][transferData.tokenAddress] >=
                transferData.amount,
            "err amount"
        );
        IERC20(transferData.tokenAddress).approve(
            address(transfer),
            transferData.amount
        );
        // call transfer to send erc20
        transfer.sendTransferERC20(transferData);
        balances[rccPacket.sender][transferData.tokenAddress] -= transferData
            .amount;

        supplies[transferData.tokenAddress] = IERC20(transferData.tokenAddress)
            .balanceOf(address(this));

        uint64 sequence = packet.getNextSequenceSend(
            rccPacket.destChain,
            transferData.destChain
        ) - 1;
        string memory sequencesKey = Strings.strConcat(
            Strings.strConcat(
                Strings.strConcat(
                    Strings.strConcat(rccPacket.destChain, "/"),
                    transferData.destChain
                ),
                "/"
            ),
            Strings.uint642str(sequence)
        );

        sequences[sequencesKey] = AgentData({
            sent: true,
            sender: rccPacket.sender,
            tokenAddress: transferData.tokenAddress,
            amount: transferData.amount
        });

        emit SendEvent(
            id,
            rccPacket.destChain,
            transferData.destChain,
            sequence
        );
        return true;
    }

    function _comingIn(
        RemoteContractCall.Data memory rccPacket,
        address tokenAddress
    ) private {
        TokenTransfer.Data memory transferPacket = transfer.getLatestPacket();

        require(
            transferPacket.receiver.equals(address(this).addressToString()) &&
                transferPacket.sender.equals(rccPacket.sender) &&
                transferPacket.srcChain.equals(rccPacket.srcChain) &&
                transferPacket.destChain.equals(rccPacket.destChain),
            "must synchronize"
        );
        // check received
        require(
            IERC20(tokenAddress).balanceOf(address(this)) >=
                supplies[tokenAddress] + transferPacket.amount.toUint256(),
            "haven't received token"
        );

        balances[transferPacket.sender][tokenAddress] += transferPacket
            .amount
            .toUint256();
    }

    function refund(
        string calldata srcChain,
        string calldata destChain,
        uint64 sequence
    ) external {
        string memory sequencesKey = Strings.strConcat(
            Strings.strConcat(
                Strings.strConcat(Strings.strConcat(srcChain, "/"), destChain),
                "/"
            ),
            Strings.uint642str(sequence)
        );

        require(sequences[sequencesKey].sent, "not exist");
        require(!refunded[sequencesKey], "refunded");
        require(
            packet.getAckStatus(srcChain, destChain, sequence) == 2,
            "not err ack"
        );
        require(
            IERC20(sequences[sequencesKey].tokenAddress).balanceOf(
                address(this)
            ) >=
                supplies[sequences[sequencesKey].tokenAddress] +
                    sequences[sequencesKey].amount,
            "haven't received token"
        );

        balances[sequences[sequencesKey].sender][
            sequences[sequencesKey].tokenAddress
        ] += sequences[sequencesKey].amount;
        refunded[sequencesKey] = true;

        supplies[sequences[sequencesKey].tokenAddress] = IERC20(
            sequences[sequencesKey].tokenAddress
        ).balanceOf(address(this));
    }
}
