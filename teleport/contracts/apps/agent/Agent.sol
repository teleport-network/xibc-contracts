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
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Agent {
    using Strings for *;
    using Bytes for *;

    mapping(string => mapping(address => uint256)) public balances; // map[sender]map[token]amount
    mapping(address => uint256) public supplies; //map[token]amount

    address public constant transferContract =
        address(0x0000000000000000000000000000000010000003);

    address public constant rccContract =
        address(0x0000000000000000000000000000000010000004);

    modifier onlyXIBCModuleRCC() {
        require(msg.sender == rccContract, "caller must be XIBC RCC module");
        _;
    }

    function send(TransferDataTypes.ERC20TransferData calldata transferData)
        external
        onlyXIBCModuleRCC
        returns (bool)
    {
        RCCDataTypes.PacketData memory rccPacket = IRCC(rccContract)
            .getLatestPacket();

        _comingIn(rccPacket, transferData.tokenAddress);

        IERC20(transferData.tokenAddress).approve(
            transferContract,
            transferData.amount
        );

        // call transfer to send erc20
        ITransfer(transferContract).sendTransferERC20(transferData);
        balances[rccPacket.sender][transferData.tokenAddress] -= transferData
            .amount;

        supplies[transferData.tokenAddress] = IERC20(transferData.tokenAddress)
            .balanceOf(address(this));

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
        require(
            IERC20(tokenAddress).balanceOf(address(this)) >=
                supplies[tokenAddress] + transferPacket.amount.toUint256() &&
                IERC20(tokenAddress).balanceOf(address(this)) >=
                balances[rccPacket.sender][tokenAddress] +
                    transferPacket.amount.toUint256(),
            "haven't received token"
        );

        balances[transferPacket.sender][
            transferPacket.token.parseAddr()
        ] += transferPacket.amount.toUint256();
    }
}
