// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../../libraries/core/Result.sol";
import "../../libraries/app/Transfer.sol";
import "../../libraries/utils/Bytes.sol";
import "../../libraries/utils/Strings.sol";
import "../../interfaces/ITransfer.sol";
import "../../interfaces/IERC20XIBC.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Transfer is ITransfer {
    using Strings for *;
    using Bytes for *;

    string private constant nativeChainName = "teleport";

    address public constant xibcModuleTransfer =
        address(0xDE152Fc3Bc10A8878677FD17c44aE633D9EBF737);
    address public constant xibcModuleAggregate =
        address(0xEE3c65B5c7F4DD0ebeD8bF046725e273e3eeeD3c);
    address public constant multiCallAddress =
        address(0x0000000000000000000000000000000010000005);

    // Token come in
    address[] public boundTokens;
    mapping(address => string[]) public boundTokenSources;
    mapping(string => TransferDataTypes.InToken) public bindings; // mapping(token/origin_chain => InToken)
    mapping(string => address) public bindingTraces; // mapping(origin_chain/origin_token => token)

    // Token out
    mapping(address => mapping(string => uint256)) public outTokens; // mapping(token, mapping(dst_chain => amount))
    // use address(0) as base token address

    TransferDataTypes.PacketData public latestPacket;

    // if back is true, srcToken should be set
    event SendPacket(
        string srcChain,
        string destChain,
        string relayChain,
        string sender,
        string receiver,
        uint256 amount,
        string token,
        string oriToken
    );

    modifier onlyXIBCModuleAggregate() {
        require(
            msg.sender == address(xibcModuleAggregate),
            "caller must be xibc aggregate module"
        );
        _;
    }

    modifier onlyXIBCModuleTransfer() {
        require(
            msg.sender == address(xibcModuleTransfer),
            "caller must be XIBC transfer module"
        );
        _;
    }

    modifier onlyMultiCall() {
        require(
            msg.sender == multiCallAddress,
            "caller must be multiCall contract address"
        );
        _;
    }

    function bindToken(
        address tokenAddres,
        string calldata oriToken,
        string calldata oriChain
    ) external onlyXIBCModuleAggregate {
        string memory bindingKey = tokenAddres
            .addressToString()
            .toSlice()
            .concat("/".toSlice())
            .toSlice()
            .concat(oriChain.toSlice());

        require(
            !bindings[bindingKey].bound,
            "source chain should not be bound before"
        );

        boundTokens.push(tokenAddres);
        boundTokenSources[tokenAddres].push(oriChain);
        bindings[bindingKey] = TransferDataTypes.InToken({
            oriToken: oriToken,
            amount: 0,
            bound: true
        });
        bindingTraces[
            oriChain.toSlice().concat("/".toSlice()).toSlice().concat(
                oriToken.toSlice()
            )
        ] = tokenAddres;
    }

    function sendTransferERC20(
        TransferDataTypes.ERC20TransferData calldata transferData
    ) external override {
        require(
            !nativeChainName.equals(transferData.destChain),
            "sourceChain can't equal to destChain"
        );

        string memory bindingKey = transferData
            .tokenAddress
            .addressToString()
            .toSlice()
            .concat("/".toSlice())
            .toSlice()
            .concat(transferData.destChain.toSlice());

        // if is crossed chain token
        if (bindings[bindingKey].bound) {
            // back to origin
            require(
                bindings[bindingKey].amount >= transferData.amount,
                "insufficient liquidity"
            );

            require(
                _burn(
                    transferData.tokenAddress,
                    msg.sender,
                    transferData.amount
                ),
                "burn token failed"
            );

            bindings[bindingKey].amount -= transferData.amount;

            emit SendPacket(
                nativeChainName,
                transferData.destChain,
                transferData.relayChain,
                msg.sender.addressToString(),
                transferData.receiver,
                transferData.amount,
                transferData.tokenAddress.addressToString(),
                bindings[bindingKey].oriToken
            );
        } else {
            // outgoing
            require(
                transferData.tokenAddress != address(0),
                "can't be zero address"
            );

            require(
                IERC20(transferData.tokenAddress).transferFrom(
                    msg.sender,
                    address(this),
                    transferData.amount
                ),
                "lock failed, unsufficient allowance"
            );

            outTokens[transferData.tokenAddress][
                transferData.destChain
            ] += transferData.amount;

            emit SendPacket(
                nativeChainName,
                transferData.destChain,
                transferData.relayChain,
                msg.sender.addressToString(),
                transferData.receiver,
                transferData.amount,
                transferData.tokenAddress.addressToString(),
                ""
            );
        }
    }

    function transferERC20(
        TransferDataTypes.ERC20TransferDataMulti calldata transferData
    ) external override onlyMultiCall {
        require(
            !nativeChainName.equals(transferData.destChain),
            "sourceChain can't equal to destChain"
        );

        string memory bindingKey = transferData
            .tokenAddress
            .addressToString()
            .toSlice()
            .concat("/".toSlice())
            .toSlice()
            .concat(transferData.destChain.toSlice());

        // if is crossed chain token
        if (bindings[bindingKey].bound) {
            // back to origin
            require(
                bindings[bindingKey].amount >= transferData.amount,
                "insufficient liquidity"
            );

            require(
                _burn(
                    transferData.tokenAddress,
                    transferData.sender,
                    transferData.amount
                ),
                "burn token failed"
            );

            bindings[bindingKey].amount -= transferData.amount;
        } else {
            // outgoing
            require(
                transferData.tokenAddress != address(0),
                "can't be zero address"
            );

            require(
                IERC20(transferData.tokenAddress).transferFrom(
                    transferData.sender,
                    address(this),
                    transferData.amount
                ),
                "lock failed, unsufficient allowance"
            );

            outTokens[transferData.tokenAddress][
                transferData.destChain
            ] += transferData.amount;
        }
    }

    function sendTransferBase(
        TransferDataTypes.BaseTransferData calldata transferData
    ) external payable override {
        require(
            !nativeChainName.equals(transferData.destChain),
            "sourceChain can't be equal to destChain"
        );

        require(msg.value > 0, "value must be greater than 0");

        outTokens[address(0)][transferData.destChain] += msg.value;

        emit SendPacket(
            nativeChainName,
            transferData.destChain,
            transferData.relayChain,
            msg.sender.addressToString(),
            transferData.receiver,
            msg.value,
            address(0).addressToString(),
            ""
        );
    }

    function transferBase(
        TransferDataTypes.BaseTransferDataMulti calldata transferData
    ) external payable override onlyMultiCall {
        require(
            !nativeChainName.equals(transferData.destChain),
            "sourceChain can't be equal to destChain"
        );

        require(msg.value > 0, "value must be greater than 0");

        outTokens[address(0)][transferData.destChain] += msg.value;
    }

    // ===========================================================================

    function onRecvPacket(TransferDataTypes.PacketData calldata packet)
        external
        override
        onlyXIBCModuleTransfer
        returns (Result.Data memory)
    {
        latestPacket = TransferDataTypes.PacketData({
            srcChain: packet.srcChain,
            destChain: packet.destChain,
            sender: packet.sender,
            receiver: packet.receiver,
            amount: packet.amount,
            token: packet.token,
            oriToken: packet.oriToken
        });

        if (bytes(packet.oriToken).length == 0) {
            // token come in
            address tokenAddress = bindingTraces[
                packet
                    .srcChain
                    .toSlice()
                    .concat("/".toSlice())
                    .toSlice()
                    .concat(packet.token.toSlice())
            ];

            string memory bindingKey = tokenAddress
                .addressToString()
                .toSlice()
                .concat("/".toSlice())
                .toSlice()
                .concat(packet.srcChain.toSlice());

            // check bindings
            if (!bindings[bindingKey].bound) {
                return
                    _newAcknowledgement(
                        false,
                        "onRecvPackt: binding is not exist"
                    );
            }

            if (
                !_mint(
                    tokenAddress,
                    packet.receiver.parseAddr(),
                    packet.amount.toUint256()
                )
            ) {
                return _newAcknowledgement(false, "onRecvPackt: mint failed");
            }

            bindings[bindingKey].amount += packet.amount.toUint256();
        } else if (packet.oriToken.parseAddr() != address(0)) {
            // ERC20 token back to origin
            if (
                packet.amount.toUint256() >
                outTokens[packet.oriToken.parseAddr()][packet.srcChain]
            ) {
                return
                    _newAcknowledgement(
                        false,
                        "onRecvPackt: amount could not be greater than locked amount"
                    );
            }

            if (
                !IERC20(packet.oriToken.parseAddr()).transfer(
                    packet.receiver.parseAddr(),
                    packet.amount.toUint256()
                )
            ) {
                return
                    _newAcknowledgement(
                        false,
                        "onRecvPackt: unlock to receiver failed"
                    );
            }

            outTokens[packet.oriToken.parseAddr()][packet.srcChain] -= packet
                .amount
                .toUint256();
        } else {
            // Base token back to origin
            if (
                packet.amount.toUint256() >
                outTokens[address(0)][packet.srcChain]
            ) {
                return
                    _newAcknowledgement(
                        false,
                        "onRecvPackt: amount could not be greater than locked amount"
                    );
            }

            if (
                !payable(packet.receiver.parseAddr()).send(
                    packet.amount.toUint256()
                )
            ) {
                return
                    _newAcknowledgement(
                        false,
                        "onRecvPackt: unlock to receiver failed"
                    );
            }

            outTokens[address(0)][packet.srcChain] -= packet.amount.toUint256();
        }

        return _newAcknowledgement(true, "");
    }

    function onAcknowledgementPacket(
        TransferDataTypes.PacketData calldata packet,
        bytes calldata result
    ) external override onlyXIBCModuleTransfer {
        if (!Bytes.equals(result, hex"01")) {
            if (bytes(packet.oriToken).length > 0) {
                // refund crossed chain token back to origin
                require(
                    _mint(
                        packet.token.parseAddr(),
                        packet.sender.parseAddr(),
                        packet.amount.toUint256()
                    ),
                    "mint back to sender failed"
                );
                bindings[
                    packet
                        .token
                        .toSlice()
                        .concat("/".toSlice())
                        .toSlice()
                        .concat(packet.destChain.toSlice())
                ].amount += packet.amount.toUint256();
            } else if (packet.token.parseAddr() != address(0)) {
                // refund native ERC20 token out
                require(
                    IERC20(packet.token.parseAddr()).transfer(
                        packet.sender.parseAddr(),
                        packet.amount.toUint256()
                    ),
                    "unlock to sender failed"
                );
                outTokens[packet.token.parseAddr()][packet.destChain] -= packet
                    .amount
                    .toUint256();
            } else {
                // refund base token out
                require(
                    payable(packet.sender.parseAddr()).send(
                        packet.amount.toUint256()
                    ),
                    "unlock to sender failed"
                );
                outTokens[address(0)][packet.destChain] -= packet
                    .amount
                    .toUint256();
            }
        }
    }

    function _newAcknowledgement(bool success, string memory errMsg)
        private
        pure
        returns (Result.Data memory)
    {
        Result.Data memory ack;
        if (success) {
            ack.result = hex"01";
        } else {
            ack.message = errMsg;
        }
        return ack;
    }

    // ===========================================================================

    function _burn(
        address destContract,
        address account,
        uint256 amount
    ) private returns (bool) {
        try IERC20XIBC(destContract).burnFrom(account, amount) {
            return true;
        } catch (bytes memory) {
            return false;
        }
    }

    function _mint(
        address destContract,
        address to,
        uint256 amount
    ) private returns (bool) {
        try IERC20XIBC(destContract).mint(to, amount) {
            return true;
        } catch (bytes memory) {
            return false;
        }
    }
}