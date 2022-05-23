// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../../libraries/packet/Packet.sol";
import "../../libraries/crosschain/CrossChain.sol";
import "../../libraries/utils/Bytes.sol";
import "../../libraries/utils/Strings.sol";
import "../../interfaces/IClientManager.sol";
import "../../interfaces/IPacket.sol";
import "../../interfaces/ICallback.sol";
import "../../interfaces/ICrossChain.sol";
import "../../interfaces/IERC20XIBC.sol";
import "../../interfaces/IAccessManager.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract CrossChain is
    Initializable,
    ICrossChain,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using Strings for *;
    using Bytes for *;

    bytes32 public constant BIND_TOKEN_ROLE = keccak256("BIND_TOKEN_ROLE");

    IPacket public packetContract;
    IClientManager public clientManager;
    IAccessManager public accessManager;

    // token come in
    address[] public override boundTokens;
    mapping(address => TokenBindingTypes.InToken) public bindings; // mapping(token => InToken)
    mapping(string => address) public override bindingTraces; // mapping(origin_chain/origin_token => token)

    // token out. use address(0) as base token address
    mapping(address => mapping(string => uint256)) public override outTokens; // mapping(token, mapping(dst_chain => amount))

    // time based supply limit
    mapping(address => TokenBindingTypes.TimeBasedSupplyLimit) public limits; // mapping(token => TimeBasedSupplyLimit)

    modifier onlyPacket() {
        require(
            msg.sender == address(packetContract),
            "caller must be packet contract"
        );
        _;
    }

    // only authorized accounts can perform related transactions
    modifier onlyAuthorizee(bytes32 role) {
        require(accessManager.hasRole(role, _msgSender()), "not authorized");
        _;
    }

    function initialize(
        address packetContractAddress,
        address clientManagerContractAddress,
        address accessManagerContractAddress
    ) public initializer {
        packetContract = IPacket(packetContractAddress);
        clientManager = IClientManager(clientManagerContractAddress);
        accessManager = IAccessManager(accessManagerContractAddress);
    }

    /**
     * @notice bind token
     * @param tokenAddress token address
     * @param oriToken origin token address
     * @param oriChain origin chain
     */
    function bindToken(
        address tokenAddress,
        string calldata oriToken,
        string calldata oriChain
    ) external onlyAuthorizee(BIND_TOKEN_ROLE) {
        require(tokenAddress != address(0), "invalid ERC20 address");

        string memory sourceChain = clientManager.getChainName();
        require(
            !sourceChain.equals(oriChain),
            "sourceChain can't equal to oriChain"
        );

        if (bindings[tokenAddress].bound) {
            // rebind
            string memory reBindKey = Strings.strConcat(
                Strings.strConcat(bindings[tokenAddress].oriChain, "/"),
                bindings[tokenAddress].oriToken
            );
            delete bindingTraces[reBindKey];
        } else {
            boundTokens.push(tokenAddress);
        }

        string memory key = Strings.strConcat(
            Strings.strConcat(oriChain, "/"),
            oriToken
        );

        bindings[tokenAddress] = TokenBindingTypes.InToken({
            oriChain: oriChain,
            oriToken: oriToken,
            amount: 0,
            bound: true
        });
        bindingTraces[key] = tokenAddress;
    }

    /**
     * @notice enable time based supply limit
     * @param tokenAddress token address
     * @param timePeriod calculation time period
     * @param timeBasedLimit time based limit
     * @param maxAmount max amount single transfer
     * @param minAmount min amount single transfer
     */
    function enableTimeBasedSupplyLimit(
        address tokenAddress,
        uint256 timePeriod,
        uint256 timeBasedLimit,
        uint256 maxAmount,
        uint256 minAmount
    ) external onlyAuthorizee(BIND_TOKEN_ROLE) {
        require(!limits[tokenAddress].enable, "already enable");
        require(
            timePeriod > 0 &&
                minAmount > 0 &&
                maxAmount > minAmount &&
                timeBasedLimit > maxAmount,
            "invalid limit"
        );

        limits[tokenAddress] = TokenBindingTypes.TimeBasedSupplyLimit({
            enable: true,
            timePeriod: timePeriod,
            timeBasedLimit: timeBasedLimit,
            maxAmount: maxAmount,
            minAmount: minAmount,
            previousTime: block.timestamp,
            currentSupply: 0
        });
    }

    /**
     * @notice disable time based supply limit
     * @param tokenAddress token address
     */
    function disableTimeBasedSupplyLimit(address tokenAddress)
        external
        onlyAuthorizee(BIND_TOKEN_ROLE)
    {
        require(limits[tokenAddress].enable, "not enable");
        delete limits[tokenAddress];
    }

    /**
     * @notice if exceeded max or less than min, retrun true
     * @param tokenAddress token address
     * @param amount token amount
     */
    function updateTimeBasedLimtSupply(address tokenAddress, uint256 amount)
        internal
        returns (bool)
    {
        TokenBindingTypes.TimeBasedSupplyLimit memory limit = limits[
            tokenAddress
        ];
        if (limit.enable) {
            if (amount < limit.minAmount || amount > limit.maxAmount) {
                return true;
            }
            if (block.timestamp - limit.previousTime < limit.timePeriod) {
                require(
                    limit.currentSupply + amount < limit.timeBasedLimit,
                    "exceeded time based limit"
                );

                limits[tokenAddress].currentSupply += amount;
            } else {
                limits[tokenAddress].previousTime = block.timestamp;
                limits[tokenAddress].currentSupply = amount;
            }
        }
        return false;
    }

    /**
     * @notice todo
     */
    function crossChainCall(
        CrossChainDataTypes.CrossChainData memory crossChainData,
        PacketTypes.Fee memory fee
    ) public payable override nonReentrant {
        string memory sourceChain = clientManager.getChainName();
        require(
            !sourceChain.equals(crossChainData.destChain) ||
                !sourceChain.equals(crossChainData.relayChain) ||
                !crossChainData.destChain.equals(crossChainData.relayChain),
            "invalid chains"
        );
        uint64 sequence = packetContract.getNextSequenceSend(
            sourceChain,
            crossChainData.destChain
        );

        // tansfer data and contractcall data can't be both empty
        require(
            crossChainData.amount != 0 || crossChainData.callData.length != 0,
            "invalid data"
        );

        bytes memory transferData;
        bytes memory callData;

        // validate transfer data contract call data
        if (crossChainData.callData.length != 0) {
            require(
                bytes(crossChainData.contractAddress).length > 0,
                "invalid contract address"
            );

            callData = abi.encode(
                PacketTypes.CallData({
                    contractAddress: crossChainData.contractAddress,
                    callData: crossChainData.callData
                })
            );
        }

        uint256 msgValue = 0;
        if (fee.tokenAddress == address(0)) {
            // add fee amount to value
            msgValue += fee.amount;
        } else if (fee.amount > 0) {
            // send fee to packet
            require(
                IERC20(fee.tokenAddress).transferFrom(
                    msg.sender,
                    address(packetContract),
                    fee.amount
                ),
                "send fee failed, insufficient allowance"
            );
        }
        if (crossChainData.amount != 0) {
            // validate transfer data
            require(
                bytes(crossChainData.receiver).length > 0,
                "invalid receiver"
            );
            string memory oriToken = "";
            if (crossChainData.tokenAddress == address(0)) {
                // transfer base token
                require(
                    msg.value == crossChainData.amount + msgValue,
                    "invalid value"
                );
                msgValue += crossChainData.amount;
                outTokens[address(0)][
                    crossChainData.destChain
                ] += crossChainData.amount;
            } else {
                // transfer ERC20
                if (bindings[crossChainData.tokenAddress].bound) {
                    // back to origin
                    require(
                        Strings.equals(
                            crossChainData.destChain,
                            bindings[crossChainData.tokenAddress].oriChain
                        ),
                        "destChain does not match the bound one"
                    );
                    require(
                        bindings[crossChainData.tokenAddress].amount >=
                            crossChainData.amount,
                        "insufficient liquidity"
                    );
                    require(
                        _burn(
                            crossChainData.tokenAddress,
                            msg.sender,
                            crossChainData.amount
                        ),
                        "burn token failed"
                    );
                    bindings[crossChainData.tokenAddress]
                        .amount -= crossChainData.amount;
                    oriToken = bindings[crossChainData.tokenAddress].oriToken;
                } else {
                    // outgoing
                    require(
                        IERC20(crossChainData.tokenAddress).transferFrom(
                            msg.sender,
                            address(this),
                            crossChainData.amount
                        ),
                        "lock failed, insufficient allowance"
                    );
                    outTokens[crossChainData.tokenAddress][
                        crossChainData.destChain
                    ] += crossChainData.amount;
                }
            }

            transferData = abi.encode(
                PacketTypes.TransferData({
                    receiver: crossChainData.receiver,
                    amount: crossChainData.amount.toBytes(),
                    token: crossChainData.tokenAddress.addressToString(),
                    oriToken: oriToken
                })
            );
        }

        PacketTypes.Packet memory packet = PacketTypes.Packet({
            srcChain: sourceChain,
            destChain: crossChainData.destChain,
            relayChain: crossChainData.relayChain,
            sequence: sequence,
            sender: msg.sender.addressToString(),
            transferData: transferData,
            callData: callData,
            callbackAddress: crossChainData.callbackAddress.addressToString(),
            feeOption: crossChainData.feeOption
        });

        packetContract.sendPacket{value: fee.amount}(packet, fee);
    }

    /**
     * @notice todo
     */
    function onRecvPacket(PacketTypes.Packet calldata packet)
        external
        override
        nonReentrant
        onlyPacket
        returns (
            uint64 code,
            bytes memory result,
            string memory message
        )
    {
        if (packet.transferData.length == 0 && packet.callData.length == 0) {
            return (1, "", "empty pcaket data");
        }

        if (packet.transferData.length > 0) {
            PacketTypes.TransferData memory transferData = abi.decode(
                packet.transferData,
                (PacketTypes.TransferData)
            );

            address tokenAddress;
            address receiver = transferData.receiver.parseAddr();
            uint256 amount = transferData.amount.toUint256();
            if (bytes(transferData.oriToken).length == 0) {
                // token come in
                tokenAddress = bindingTraces[
                    Strings.strConcat(
                        Strings.strConcat(packet.srcChain, "/"),
                        transferData.token
                    )
                ];
                // check bindings
                if (!bindings[tokenAddress].bound) {
                    return (2, "", "token not bound");
                }
                if (updateTimeBasedLimtSupply(tokenAddress, amount)) {
                    return (2, "", "invalid amount");
                }
                if (!_mint(tokenAddress, receiver, amount)) {
                    return (2, "", "mint failed");
                }
                bindings[tokenAddress].amount += amount;
            } else {
                tokenAddress = transferData.oriToken.parseAddr();

                if (tokenAddress != address(0)) {
                    // ERC20 token back to origin
                    if (amount > outTokens[tokenAddress][packet.srcChain]) {
                        return (2, "", "amount is greater than locked");
                    }
                    if (updateTimeBasedLimtSupply(tokenAddress, amount)) {
                        return (2, "", "exceed the limit");
                    }
                    if (!IERC20(tokenAddress).transfer(receiver, amount)) {
                        return (2, "", "unlock to receiver failed");
                    }
                    outTokens[tokenAddress][packet.srcChain] -= amount;
                } else {
                    // Base token back to origin
                    if (amount > outTokens[address(0)][packet.srcChain]) {
                        return (2, "", "amount is greater than locked");
                    }
                    if (updateTimeBasedLimtSupply(tokenAddress, amount)) {
                        return (2, "", "exceed the limit");
                    }
                    (bool success, ) = receiver.call{value: amount}("");
                    if (!success) {
                        return (2, "", "unlock to receiver failed");
                    }
                    outTokens[address(0)][packet.srcChain] -= amount;
                }
            }
        }

        if (packet.transferData.length > 0) {
            PacketTypes.CallData memory callData = abi.decode(
                packet.callData,
                (PacketTypes.CallData)
            );
            (bool success, bytes memory res) = callData
                .contractAddress
                .parseAddr()
                .call(callData.callData);
            if (!success) {
                return (3, "", "execute call data failed");
            }
            return (0, res, "");
        }

        return (0, "", "");
    }

    /**
     * @notice todo
     */
    function onAcknowledgementPacket(
        PacketTypes.Packet memory packet,
        uint64 code,
        bytes memory result,
        string memory message
    ) public override nonReentrant onlyPacket {
        if (code != 0) {
            // refund tokens
            PacketTypes.TransferData memory transferData = abi.decode(
                packet.transferData,
                (PacketTypes.TransferData)
            );

            address sender = packet.sender.parseAddr();
            address tokenAddress = transferData.token.parseAddr();
            uint256 amount = transferData.amount.toUint256();

            if (bytes(transferData.oriToken).length > 0) {
                // refund crossed chain token
                require(
                    _mint(tokenAddress, sender, amount),
                    "mint back to sender failed"
                );
                bindings[tokenAddress].amount += amount;
            } else if (tokenAddress != address(0)) {
                // refund native ERC20 token
                require(
                    IERC20(tokenAddress).transfer(sender, amount),
                    "unlock ERC20 token to sender failed"
                );
                outTokens[tokenAddress][packet.destChain] -= amount;
            } else {
                // refund base token
                (bool success, ) = sender.call{value: amount}("");
                require(success, "unlock base token to sender failed");
                outTokens[tokenAddress][packet.destChain] -= amount;
            }
        }
        ICallback(packet.callbackAddress.parseAddr()).callback(
            code,
            result,
            message
        );
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

    // ===========================================================================

    /**
     * @notice todo
     */
    function getBindings(address token)
        external
        view
        override
        returns (TokenBindingTypes.InToken memory inToken)
    {
        return bindings[token];
    }
}