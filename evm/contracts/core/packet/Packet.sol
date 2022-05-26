// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

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
    using Bytes for *;

    IClientManager public clientManager;
    IAccessManager public accessManager;
    ICrossChain public crossChain;

    mapping(bytes => uint64) public sequences;
    mapping(bytes => bytes32) public commitments;
    mapping(bytes => bool) public receipts;
    mapping(bytes => uint8) public ackStatus; // 0 => not found , 1 => success , 2 => err
    mapping(bytes => PacketTypes.Acknowledgement) public acks;
    mapping(bytes => PacketTypes.Fee) public packetFees; // TBD: delete acked packet fee

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");

    PacketTypes.Packet public latestPacket;

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
     * @param packetBytes packet bytes
     */
    event PacketSent(bytes packetBytes);

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

    // only onlyCrossChainContract can perform related transactions
    modifier onlyCrossChainContract() {
        require(
            address(crossChain) == _msgSender(),
            "only cross chain contract authorized"
        );
        _;
    }

    // only authorized accounts can perform related transactions
    modifier onlyAuthorizee(bytes32 role) {
        require(accessManager.hasRole(role, _msgSender()), "not authorized");
        _;
    }

    /**
     * @notice sendPacket is called by a module in order to send an XIBC packet with single data.
     * @param packet xibc packet
     * @param fee packet fee
     */
    function sendPacket(
        PacketTypes.Packet memory packet,
        PacketTypes.Fee memory fee
    ) public payable override whenNotPaused onlyCrossChainContract {
        require(packet.sequence > 0, "packet sequence cannot be 0");

        // TODO: validate packet data

        // Notice: must sent token to this contract before set packet fee
        packetFees[
            Host.commonUniqueKey(
                packet.srcChain,
                packet.destChain,
                packet.sequence
            )
        ] = fee;

        if (bytes(packet.relayChain).length > 0) {
            require(
                address(clientManager.getClient(packet.relayChain)) !=
                    address(0),
                "client not found"
            );
        } else {
            require(
                address(clientManager.getClient(packet.destChain)) !=
                    address(0),
                "client not found"
            );
        }

        bytes memory nextSequenceSendKey = Host.nextSequenceSendKey(
            packet.srcChain,
            packet.destChain
        );

        if (sequences[nextSequenceSendKey] == 0) {
            sequences[nextSequenceSendKey] = 1;
        }

        require(
            packet.sequence == sequences[nextSequenceSendKey],
            "packet sequence ≠ next send sequence"
        );

        sequences[nextSequenceSendKey]++;

        bytes memory bz = abi.encode(packet);
        commitments[
            Host.packetCommitmentKey(
                packet.srcChain,
                packet.destChain,
                packet.sequence
            )
        ] = sha256(Bytes.fromBytes32(sha256(bz)));
        emit PacketSent(bz);
    }

    /**
     * @notice recvPacket is called by any relayer in order to receive & process an XIBC packet
     * @param packetBytes xibc packet bytes
     * @param proof proof commit
     * @param height proof height
     */
    function recvPacket(
        bytes calldata packetBytes,
        bytes calldata proof,
        Height.Data calldata height
    )
        external
        override
        nonReentrant
        whenNotPaused
        onlyAuthorizee(RELAYER_ROLE)
    {
        PacketTypes.Packet memory packet = abi.decode(
            packetBytes,
            (PacketTypes.Packet)
        );
        latestPacket = packet;

        require(
            Strings.equals(packet.destChain, clientManager.getChainName()),
            "invalid destChain"
        );

        bytes memory packetReceiptKey = Host.packetReceiptKey(
            packet.srcChain,
            packet.destChain,
            packet.sequence
        );

        require(!receipts[packetReceiptKey], "packet has been received");

        bytes memory packetCommitment = Bytes.fromBytes32(sha256(packetBytes));
        _verifyPacketCommitment(
            _msgSender(),
            packet.sequence,
            packet.srcChain,
            packet.destChain,
            packet.relayChain,
            proof,
            height,
            packetCommitment
        );

        receipts[packetReceiptKey] = true;

        emit PacketReceived(packet);

        PacketTypes.Acknowledgement memory ack;

        try crossChain.onRecvPacket(packet) returns (
            uint64 code,
            bytes memory result,
            string memory message
        ) {
            ack.code = code;
            ack.result = result;
            ack.message = message;
        } catch (bytes memory res) {
            ack.code = 1;
            ack.result = "";
            ack.message = string(res);
        }

        ack.relayer = msg.sender.addressToString();
        ack.feeOption = packet.feeOption;

        bytes memory ackBytes = abi.encode(ack);
        _writeAcknowledgement(
            packet.sequence,
            packet.srcChain,
            packet.destChain,
            packet.relayChain,
            ackBytes
        );

        emit AckWritten(packet, ackBytes);
    }

    /**
     * @notice Verify packet commitment
     * todo
     */
    function _verifyPacketCommitment(
        address sender,
        uint64 sequence,
        string memory sourceChain,
        string memory destChain,
        string memory relayChain,
        bytes memory proof,
        Height.Data memory height,
        bytes memory commitBytes
    ) private view {
        IClient client;
        if (
            Strings.equals(destChain, clientManager.getChainName()) &&
            bytes(relayChain).length > 0
        ) {
            client = clientManager.getClient(relayChain);
        } else {
            client = clientManager.getClient(sourceChain);
        }
        require(address(client) != address(0), "client not found");

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
     * @notice _writeAcknowledgement is called by a module in order to send back a ack message
     * todo
     */
    function _writeAcknowledgement(
        uint64 sequence,
        string memory sourceChain,
        string memory destChain,
        string memory relayChain,
        bytes memory acknowledgement
    ) private {
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

        require(address(client) != address(0), "client not found");

        commitments[packetAcknowledgementKey] = sha256(acknowledgement);
    }

    /**
     * @notice acknowledgePacket is called by relayer in order to receive an XIBC acknowledgement
     * @param packetBytes xibc packet bytes
     * @param acknowledgement acknowledgement from dest chain
     * @param proofAcked ack proof commit
     * @param height ack proof height
     */
    function acknowledgePacket(
        bytes calldata packetBytes,
        bytes calldata acknowledgement,
        bytes calldata proofAcked,
        Height.Data calldata height
    ) external override nonReentrant whenNotPaused {
        PacketTypes.Packet memory packet = abi.decode(
            packetBytes,
            (PacketTypes.Packet)
        );

        require(
            Strings.equals(packet.srcChain, clientManager.getChainName()),
            "invalid packet"
        );

        bytes memory packetCommitmentKey = Host.packetCommitmentKey(
            packet.srcChain,
            packet.destChain,
            packet.sequence
        );

        require(
            commitments[packetCommitmentKey] == sha256(packetBytes),
            "commitment bytes are not equal"
        );

        _verifyPacketAcknowledgement(
            _msgSender(),
            packet.sequence,
            packet.srcChain,
            packet.destChain,
            packet.relayChain,
            acknowledgement,
            proofAcked,
            height
        );

        delete commitments[packetCommitmentKey];

        emit AckPacket(packet, acknowledgement);

        PacketTypes.Acknowledgement memory ack = abi.decode(
            acknowledgement,
            (PacketTypes.Acknowledgement)
        );

        bytes memory key = Host.commonUniqueKey(
            packet.srcChain,
            packet.destChain,
            packet.sequence
        );

        if (ack.code == 0) {
            ackStatus[key] = 1;
        } else {
            ackStatus[key] = 2;
        }

        acks[
            Host.commonUniqueKey(
                packet.srcChain,
                packet.destChain,
                packet.sequence
            )
        ] = ack;

        crossChain.onAcknowledgementPacket(
            packet,
            ack.code,
            ack.result,
            ack.message
        );

        _sendPacketFeeToRelayer(
            packet.srcChain,
            packet.destChain,
            packet.sequence,
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
    function _sendPacketFeeToRelayer(
        string memory sourceChain,
        string memory destChain,
        uint64 sequence,
        address relayer
    ) private {
        PacketTypes.Fee memory fee = packetFees[
            Host.commonUniqueKey(sourceChain, destChain, sequence)
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
    function _verifyPacketAcknowledgement(
        address sender,
        uint64 sequence,
        string memory sourceChain,
        string memory destChain,
        string memory relayChain,
        bytes memory acknowledgement,
        bytes memory proofAcked,
        Height.Data memory height
    ) private view {
        IClient client;
        if (
            Strings.equals(sourceChain, clientManager.getChainName()) &&
            bytes(relayChain).length > 0
        ) {
            require(
                address(clientManager.getClient(relayChain)) != address(0),
                "client not found"
            );
            client = clientManager.getClient(relayChain);
        } else {
            require(
                address(clientManager.getClient(destChain)) != address(0),
                "client not found"
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
        return
            ackStatus[Host.commonUniqueKey(sourceChain, destChain, sequence)];
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
        bytes memory key = Host.commonUniqueKey(
            sourceChain,
            destChain,
            sequence
        );

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
    function getLatestPacket()
        external
        view
        override
        returns (PacketTypes.Packet memory packet)
    {
        return latestPacket;
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
