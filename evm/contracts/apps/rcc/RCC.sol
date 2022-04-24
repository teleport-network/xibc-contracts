// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../../core/client/ClientManager.sol";
import "../../libraries/app/RCC.sol";
import "../../libraries/packet/Packet.sol";
import "../../libraries/utils/Bytes.sol";
import "../../libraries/utils/Strings.sol";
import "../../interfaces/IRCC.sol";
import "../../interfaces/IPacket.sol";
import "../../interfaces/IAccessManager.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract RCC is
    Initializable,
    IRCC,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using Strings for *;
    using Bytes for *;

    bytes32 public constant MULTISEND_ROLE = keccak256("MULTISEND_ROLE");

    string private constant PORT = "CONTRACT";

    IPacket public packet;
    IClientManager public clientManager;
    IAccessManager public accessManager;

    mapping(bytes32 => bytes) public override acks;

    RCCDataTypes.RCCPacketData public latestPacket;

    event Ack(bytes32 indexed dataHash, bytes ack);

    modifier onlyPacket() {
        require(msg.sender == address(packet), "caller not packet contract");
        _;
    }

    // only authorized accounts can perform related transactions
    modifier onlyAuthorizee(bytes32 role) {
        require(accessManager.hasRole(role, _msgSender()), "not authorized");
        _;
    }

    function initialize(
        address packetContract,
        address clientMgrContract,
        address accessManagerContract
    ) public initializer {
        packet = IPacket(packetContract);
        clientManager = IClientManager(clientMgrContract);
        accessManager = IAccessManager(accessManagerContract);
    }

    function sendRemoteContractCall(
        RCCDataTypes.RCCData memory rccData,
        PacketTypes.Fee memory fee
    ) public payable override {
        string memory sourceChain = clientManager.getChainName();
        require(
            !sourceChain.equals(rccData.destChain),
            "sourceChain can't equal to destChain"
        );

        uint64 sequence = packet.getNextSequenceSend(
            sourceChain,
            rccData.destChain
        );

        // send packet
        string[] memory ports = new string[](1);
        bytes[] memory dataList = new bytes[](1);
        ports[0] = PORT;
        dataList[0] = abi.encode(
            RCCDataTypes.RCCPacketData({
                srcChain: sourceChain,
                destChain: rccData.destChain,
                sequence: sequence,
                sender: msg.sender.addressToString(),
                contractAddress: rccData.contractAddress,
                data: rccData.data
            })
        );

        PacketTypes.Packet memory crossPacket = PacketTypes.Packet({
            sequence: sequence,
            sourceChain: sourceChain,
            destChain: rccData.destChain,
            relayChain: rccData.relayChain,
            ports: ports,
            dataList: dataList
        });

        if (fee.tokenAddress == address(0)) {
            require(msg.value == fee.amount, "invalid value");
            packet.sendPacket{value: fee.amount}(crossPacket, fee);
        } else {
            require(msg.value == 0, "invalid value");
            // send fee to packet
            require(
                IERC20(fee.tokenAddress).transferFrom(
                    msg.sender,
                    address(packet),
                    fee.amount
                ),
                "lock failed, insufficient allowance"
            );
            packet.sendPacket(crossPacket, fee);
        }
    }

    function remoteContractCall(RCCDataTypes.RCCDataMulti calldata rccData)
        external
        override
        onlyAuthorizee(MULTISEND_ROLE)
        returns (bytes memory)
    {
        string memory sourceChain = clientManager.getChainName();
        require(
            !sourceChain.equals(rccData.destChain),
            "sourceChain can't equal to destChain"
        );

        return
            abi.encode(
                RCCDataTypes.RCCPacketData({
                    srcChain: sourceChain,
                    destChain: rccData.destChain,
                    sequence: packet.getNextSequenceSend(
                        sourceChain,
                        rccData.destChain
                    ),
                    sender: rccData.sender.addressToString(),
                    contractAddress: rccData.contractAddress,
                    data: rccData.data
                })
            );
    }

    // ===========================================================================

    function onRecvPacket(bytes calldata data)
        external
        override
        onlyPacket
        nonReentrant
        returns (PacketTypes.Result memory)
    {
        RCCDataTypes.RCCPacketData memory packetData = abi.decode(
            data,
            (RCCDataTypes.RCCPacketData)
        );
        require(
            packetData.contractAddress.parseAddr() != address(this),
            "illegal operation"
        );

        require(
            packetData.contractAddress.parseAddr() != address(packet),
            "illegal operation"
        );

        latestPacket = packetData;

        PacketTypes.Result memory result;
        (bool success, bytes memory res) = packetData
            .contractAddress
            .parseAddr()
            .call(packetData.data);
        if (!success) {
            if (res.length != 0) {
                result.message = string(res);
            } else {
                result.message = "onRecvPackt: execute packet failed";
            }
        } else {
            if (res.length == 0) {
                result.result = hex"01";
            } else {
                result.result = res;
            }
        }

        return result;
    }

    function onAcknowledgementPacket(bytes calldata data, bytes calldata result)
        external
        override
        onlyPacket
    {
        acks[sha256(data)] = result;
        emit Ack(sha256(data), result);
    }

    // ===========================================================================

    function getLatestPacket()
        external
        view
        override
        returns (RCCDataTypes.RCCPacketData memory)
    {
        return latestPacket;
    }
}
