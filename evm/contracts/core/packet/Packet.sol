// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../client/ClientManager.sol";
import "../../libraries/packet/Packet.sol";
import "../../libraries/host/Host.sol";
import "../../interfaces/IClientManager.sol";
import "../../interfaces/IClient.sol";
import "../../interfaces/IPacket.sol";
import "../../interfaces/ICrossChain.sol";
import "../../interfaces/IAccessManager.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract Packet is
    Initializable,
    OwnableUpgradeable,
    IPacket,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using Strings for *;
    using Bytes for *;

    IClientManager public clientManager;
    IAccessManager public accessManager;
    ICrossChain public crossChain;

    mapping(bytes => uint64) public sequences;
    mapping(bytes => bytes32) public commitments;
    mapping(bytes => bool) public receipts;
    mapping(bytes => uint8) public ackStatus; // 0 => not found , 1 => success , 2 => err
    mapping(bytes => PacketTypes.Fee) public packetFees; // TBD: delete acked packet fee

    bytes32 public constant MULTISEND_ROLE = keccak256("MULTISEND_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    PacketTypes.PacketData public latestPacketData;

    /**
     * @notice initialize
     * @param clientManagerContract clientManager address
     * @param accessManagerContract accessManager address
     * @param crossChainContract crossChainContract address
     */
    function initialize(
        address clientManagerContract,
        address accessManagerContract,
        address crossChainContract
    ) public initializer {
        require(
            clientManagerContract != address(0) &&
                accessManagerContract != address(0) &&
                crossChainContract != address(0),
            "clientManager, accessManager and crossChainContract cannot be empty"
        );
        clientManager = IClientManager(clientManagerContract);
        accessManager = IAccessManager(accessManagerContract);
        crossChain = ICrossChain(crossChainContract);
    }

    /**
     * @notice Event triggered when the packet has been sent
     * @param packet packet data
     */
    event PacketSent(PacketTypes.Packet packet);

    /**
     * @notice Event triggered when the packet has been received
     * @param packet packet data
     */
    event PacketReceived(PacketTypes.Packet packet);

    /**
     * @notice Event triggered when the write ack
     * @param packet packet data
     * @param ack ack bytes
     */
    event AckPacket(PacketTypes.Packet packet, bytes ack);

    /**
     * @notice Event triggered when receive ack
     * @param packet packet data
     * @param ack ack bytes
     */
    event AckWritten(PacketTypes.Packet packet, bytes ack);

    // only self can perform related transactions
    modifier onlySelf() {
        require(address(this) == _msgSender(), "not authorized");
        _;
    }

    // only authorized accounts can perform related transactions
    modifier onlyAuthorizee(bytes32 role) {
        require(accessManager.hasRole(role, _msgSender()), "not authorized");
        _;
    }

    /**
     * @notice SendPacket is called by a module in order to send an XIBC packet with single data.
     * @param packetData xibc packet data
     * @param fee packet fee
     */
    function sendPacket(
        PacketTypes.PacketData memory packetData,
        PacketTypes.Fee memory fee
    ) public payable override whenNotPaused {
        require(packetData.sequence > 0, "packet sequence cannot be 0");

        // TODO: validate packet data

        // Notice: must sent token to this contract before set packet fee
        packetFees[
            Host.ackStatusKey(
                packetData.srcChain,
                packetData.destChain,
                packetData.sequence
            )
        ] = fee;

        if (bytes(packetData.relayChain).length > 0) {
            require(
                address(clientManager.getClient(packetData.relayChain)) !=
                    address(0),
                "light client not found"
            );
        } else {
            require(
                address(clientManager.getClient(packetData.destChain)) !=
                    address(0),
                "light client not found"
            );
        }

        bytes memory nextSequenceSendKey = Host.nextSequenceSendKey(
            packetData.srcChain,
            packetData.destChain
        );

        if (sequences[nextSequenceSendKey] == 0) {
            sequences[nextSequenceSendKey] = 1;
        }

        require(
            packetData.sequence == sequences[nextSequenceSendKey],
            "packet sequence ≠ next send sequence"
        );

        sequences[nextSequenceSendKey]++;

        bytes memory data = abi.encode(packetData);
        commitments[
            Host.packetCommitmentKey(
                packetData.srcChain,
                packetData.destChain,
                packetData.sequence
            )
        ] = sha256(Bytes.fromBytes32(sha256(data)));
        emit PacketSent(PacketTypes.Packet({data: data}));
    }

    /**
     * @notice recvPacket is called by any relayer in order to receive & process an XIBC packet
     * @param packet xibc packet
     * @param proof proof commit
     * @param height proof height
     */
    function recvPacket(
        PacketTypes.Packet calldata packet,
        bytes calldata proof,
        Height.Data calldata height
    ) external override nonReentrant whenNotPaused {
        PacketTypes.PacketData memory packetData = abi.decode(
            packet.data,
            (PacketTypes.PacketData)
        );
        latestPacketData = packetData;

        require(
            Strings.equals(packetData.destChain, clientManager.getChainName()),
            "invalid destChain"
        );

        bytes memory packetReceiptKey = Host.packetReceiptKey(
            packetData.srcChain,
            packetData.destChain,
            packetData.sequence
        );

        require(!receipts[packetReceiptKey], "packet has been received");

        verifyPacketCommitment(
            _msgSender(),
            packetData.sequence,
            packetData.srcChain,
            packetData.destChain,
            packetData.relayChain,
            proof,
            height,
            Bytes.fromBytes32(sha256(packet.data))
        );

        receipts[packetReceiptKey] = true;

        emit PacketReceived(packet);

        PacketTypes.Acknowledgement memory ack;
        (ack.code, ack.result, ack.message) = crossChain.onRecvPacket(
            packetData
        );

        ack.relayer = msg.sender.addressToString();
        bytes memory ackBytes = abi.encode(ack);
        writeAcknowledgement(
            packetData.sequence,
            packetData.srcChain,
            packetData.destChain,
            packetData.relayChain,
            ackBytes
        );

        emit AckWritten(packet, ackBytes);
    }

    /**
     * @notice Verify packet commitment
     */
    function verifyPacketCommitment(
        address sender,
        uint64 sequence,
        string memory sourceChain,
        string memory destChain,
        string memory relayChain,
        bytes memory proof,
        Height.Data memory height,
        bytes memory commitBytes
    ) internal view {
        IClient client;
        if (
            Strings.equals(destChain, clientManager.getChainName()) &&
            bytes(relayChain).length > 0
        ) {
            client = clientManager.getClient(relayChain);
        } else {
            client = clientManager.getClient(sourceChain);
        }
        require(address(client) != address(0), "light client not found!");

        client.verifyPacketCommitment(
            sender,
            height,
            proof,
            sourceChain,
            destChain,
            sequence,
            commitBytes
        );
    }

    /**
     * @notice writeAcknowledgement is called by a module in order to send back a ack message
     */
    function writeAcknowledgement(
        uint64 sequence,
        string memory sourceChain,
        string memory destChain,
        string memory relayChain,
        bytes memory acknowledgement
    ) internal {
        bytes memory packetAcknowledgementKey = Host.packetAcknowledgementKey(
            sourceChain,
            destChain,
            sequence
        );
        require(
            commitments[packetAcknowledgementKey] == bytes32(0),
            "acknowledgement for packet already exists"
        );
        require(acknowledgement.length != 0, "acknowledgement cannot be empty");

        IClient client;
        if (
            bytes(relayChain).length > 0 &&
            Strings.equals(destChain, clientManager.getChainName())
        ) {
            client = clientManager.getClient(relayChain);
        } else {
            client = clientManager.getClient(sourceChain);
        }

        require(address(client) != address(0), "light client not found");

        commitments[packetAcknowledgementKey] = sha256(acknowledgement);
        setMaxAckSequence(sourceChain, destChain, sequence);
    }

    /**
     * @notice acknowledgePacket is called by relayer in order to receive an XIBC acknowledgement
     * @param packet xibc packet
     * @param acknowledgement acknowledgement from dest chain
     * @param proofAcked ack proof commit
     * @param height ack proof height
     */
    function acknowledgePacket(
        PacketTypes.Packet calldata packet,
        bytes calldata acknowledgement,
        bytes calldata proofAcked,
        Height.Data calldata height
    ) external override nonReentrant whenNotPaused {
        PacketTypes.PacketData memory packetData = abi.decode(
            packet.data,
            (PacketTypes.PacketData)
        );

        require(
            Strings.equals(packetData.srcChain, clientManager.getChainName()),
            "invalid packet"
        );

        bytes memory packetCommitmentKey = Host.packetCommitmentKey(
            packetData.srcChain,
            packetData.destChain,
            packetData.sequence
        );

        require(
            commitments[packetCommitmentKey] == sha256(packet.data),
            "commitment bytes are not equal"
        );

        verifyPacketAcknowledgement(
            _msgSender(),
            packetData.sequence,
            packetData.srcChain,
            packetData.destChain,
            packetData.relayChain,
            acknowledgement,
            proofAcked,
            height
        );

        delete commitments[packetCommitmentKey];

        setMaxAckSequence(
            packetData.srcChain,
            packetData.destChain,
            packetData.sequence
        );

        emit AckPacket(packet, acknowledgement);

        PacketTypes.Acknowledgement memory ack = abi.decode(
            acknowledgement,
            (PacketTypes.Acknowledgement)
        );

        bytes memory key = Host.ackStatusKey(
            packetData.srcChain,
            packetData.destChain,
            packetData.sequence
        );

        if (ack.code == 0) {
            ackStatus[key] = 1;
        } else {
            ackStatus[key] = 2;
        }

        crossChain.onAcknowledgementPacket(
            packet.data,
            ack.code,
            ack.result,
            ack.message
        );

        sendPacketFeeToRelayer(
            packetData.srcChain,
            packetData.destChain,
            packetData.sequence,
            ack.relayer.parseAddr()
        );
    }

    /**
     * @notice send packet fee to relayer
     * @param sourceChain source chain name
     * @param destChain destination chain name
     * @param sequence sequence
     * @param relayer relayer address
     */
    function sendPacketFeeToRelayer(
        string memory sourceChain,
        string memory destChain,
        uint64 sequence,
        address relayer
    ) internal {
        PacketTypes.Fee memory fee = packetFees[
            Host.ackStatusKey(sourceChain, destChain, sequence)
        ];
        if (fee.tokenAddress == address(0)) {
            payable(relayer).transfer(fee.amount);
        } else {
            require(IERC20(fee.tokenAddress).transfer(relayer, fee.amount), "");
        }
    }

    /**
     * @notice verify packet acknowledgement
     */
    function verifyPacketAcknowledgement(
        address sender,
        uint64 sequence,
        string memory sourceChain,
        string memory destChain,
        string memory relayChain,
        bytes memory acknowledgement,
        bytes memory proofAcked,
        Height.Data memory height
    ) internal view {
        IClient client;
        if (
            Strings.equals(sourceChain, clientManager.getChainName()) &&
            bytes(relayChain).length > 0
        ) {
            require(
                address(clientManager.getClient(relayChain)) != address(0),
                "light client not found"
            );
            client = clientManager.getClient(relayChain);
        } else {
            require(
                address(clientManager.getClient(destChain)) != address(0),
                "light client not found"
            );
            client = clientManager.getClient(destChain);
        }
        client.verifyPacketAcknowledgement(
            sender,
            height,
            proofAcked,
            sourceChain,
            destChain,
            sequence,
            Bytes.fromBytes32(sha256(acknowledgement))
        );
    }

    /**
     * @notice set max ack sequence
     * @param sourceChain source chain name
     * @param destChain destination chain name
     * @param sequence max ack sequence
     */
    function setMaxAckSequence(
        string memory sourceChain,
        string memory destChain,
        uint64 sequence
    ) internal {
        uint64 currentMaxAckSeq = sequences[
            Host.MaxAckSeqKey(sourceChain, destChain)
        ];
        if (sequence > currentMaxAckSeq) {
            currentMaxAckSeq = sequence;
        }
        sequences[Host.MaxAckSeqKey(sourceChain, destChain)] = currentMaxAckSeq;
    }

    /**
     * @notice get packet next sequence to send
     * @param sourceChain name of source chain
     * @param destChain name of destination chain
     */
    function getNextSequenceSend(
        string memory sourceChain,
        string memory destChain
    ) public view override returns (uint64) {
        uint64 seq = sequences[
            Host.nextSequenceSendKey(sourceChain, destChain)
        ];
        if (seq == 0) {
            seq = 1;
        }
        return seq;
    }

    /**
     * @notice get the next sequence of sourceChain/destChain
     * @param sourceChain source chain name
     * @param destChain destination chain name
     * @param sequence sequence
     */
    function getAckStatus(
        string calldata sourceChain,
        string calldata destChain,
        uint64 sequence
    ) external view override returns (uint8) {
        return ackStatus[Host.ackStatusKey(sourceChain, destChain, sequence)];
    }

    /**
     * @notice set packet fee
     * @param sourceChain source chain name
     * @param destChain destination chain name
     * @param sequence sequence
     * @param amount add fee amount
     */
    function addPacketFee(
        string memory sourceChain,
        string memory destChain,
        uint64 sequence,
        uint256 amount
    ) public payable whenNotPaused {
        bytes memory key = Host.ackStatusKey(sourceChain, destChain, sequence);

        require(ackStatus[key] == uint8(0), "invalid packet status");

        PacketTypes.Fee memory fee = packetFees[key];

        if (fee.tokenAddress == address(0)) {
            require(msg.value > 0 && msg.value == amount, "invalid value");
        } else {
            require(msg.value == 0, "invalid value");
            require(
                IERC20(fee.tokenAddress).transferFrom(
                    msg.sender,
                    address(this),
                    amount
                ),
                "transfer ERC20 failed"
            );
        }

        packetFees[key].amount += amount;
    }

    /**
     * @notice todo
     */
    function getLatestPacketData()
        external
        view
        override
        returns (PacketTypes.PacketData memory packetData)
    {
        return latestPacketData;
    }

    /**
     * @dev Pauses all cross-chain transfers.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function pause() public virtual onlyAuthorizee(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses all cross-chain transfers.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function unpause() public virtual onlyAuthorizee(PAUSER_ROLE) {
        _unpause();
    }
}
