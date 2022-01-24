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
import "../../proto/RemoteContractCall.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Agent is Initializable, OwnableUpgradeable {
    using Strings for *;
    using Bytes for *;

    ITransfer public transfer;
    IRCC public rcc;

    mapping(string => mapping(address => uint256)) public balances; // map[sender]map[token]amount
    mapping(address => uint256) public supplies; //map[token]amount

    modifier onlyXIBCModuleRCC() {
        require(msg.sender == address(rcc), "caller must be XIBC RCC Contract");
        _;
    }

    function initialize(address transferContract, address rccContract)
        public
        initializer
    {
        transfer = ITransfer(transferContract);
        rcc = IRCC(rccContract);
    }

    function send(TransferDataTypes.ERC20TransferData calldata transferData)
        external
        onlyXIBCModuleRCC
        returns (bool)
    {
        RemoteContractCall.Data memory rccPacket = rcc.getLatestPacket();

        _comingIn(rccPacket, transferData.tokenAddress);

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

        return true;
    }

    function _comingIn(
        RemoteContractCall.Data memory rccPacket,
        address tokenAddress
    ) private {
        TokenTransfer.Data memory transferPacket = transfer.getLatestPacket();

        require(
            transferPacket.receiver.equals(address(this).addressToString())&&
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
