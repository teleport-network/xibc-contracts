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

contract Agent {
    receive() external payable {}

    using Strings for *;
    using Bytes for *;

    struct AgentData {
        bool sent;
        string sender;
        address tokenAddress;
        uint256 amount;
    }

    mapping(string => mapping(address => uint256)) public balances; // map[sender]map[token]amount
    mapping(address => uint256) public supplies; //map[token]amount
    mapping(string => AgentData) public sequences; //map[srcChain/destChain/sequence]transferPacketData
    mapping(string => bool) public refunded;

    address public constant transferContract =
        address(0x0000000000000000000000000000000010000003);

    address public constant rccContract =
        address(0x0000000000000000000000000000000010000004);

    address public constant xibcModulePacket =
        address(0x0000000000000000000000000000000010000008);

    modifier onlyXIBCModuleRCC() {
        require(msg.sender == rccContract, "caller must be XIBC RCC module");
        _;
    }

    event SendEvent(
        bytes id,
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

        RCCDataTypes.PacketData memory rccPacket = IRCC(rccContract)
            .getLatestPacket();

        _comingIn(rccPacket, transferData.tokenAddress);

        require(
            balances[rccPacket.sender][transferData.tokenAddress] >=
                transferData.amount,
            "err amount"
        );
        if (transferData.tokenAddress != address(0)) {
            IERC20(transferData.tokenAddress).approve(
                address(transferContract),
                transferData.amount
            );
            // call transfer to send erc20
            ITransfer(transferContract).sendTransferERC20(transferData);
            supplies[transferData.tokenAddress] = IERC20(
                transferData.tokenAddress
            ).balanceOf(address(this));
        } else {
            // call transfer to send base
            ITransfer(transferContract).sendTransferBase{
                value: transferData.amount
            }(
                TransferDataTypes.BaseTransferData({
                    receiver: transferData.receiver,
                    destChain: transferData.destChain,
                    relayChain: transferData.relayChain
                })
            );
            supplies[transferData.tokenAddress] = address(this).balance;
        }

        balances[rccPacket.sender][transferData.tokenAddress] -= transferData
            .amount;

        uint64 sequence = IPacket(xibcModulePacket).getNextSequenceSend(
            rccPacket.destChain,
            transferData.destChain
        );
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
        RCCDataTypes.PacketData memory rccPacket,
        address tokenAddress
    ) private {
        TransferDataTypes.PacketData memory transferPacket = ITransfer(
            transferContract
        ).getLatestPacket();

        require(
            transferPacket.receiver.equals(address(this).addressToString()) &&
                transferPacket.sender.equals(rccPacket.sender) &&
                transferPacket.srcChain.equals(rccPacket.srcChain) &&
                transferPacket.destChain.equals(rccPacket.destChain),
            "must synchronize"
        );
        // check received
        if (tokenAddress != address(0)) {
            require(
                IERC20(tokenAddress).balanceOf(address(this)) >=
                    supplies[tokenAddress] + transferPacket.amount.toUint256(),
                "haven't received token"
            );
        } else {
            require(
                address(this).balance >=
                    supplies[tokenAddress] + transferPacket.amount.toUint256(),
                "haven't received token"
            );
        }

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
            IPacket(xibcModulePacket).getAckStatus(
                srcChain,
                destChain,
                sequence
            ) == 2,
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
