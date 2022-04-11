// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../client/ClientManager.sol";
import "../../libraries/packet/Packet.sol";
import "../../libraries/host/Host.sol";
import "../../interfaces/IClientManager.sol";
import "../../interfaces/IClient.sol";
import "../../interfaces/IModule.sol";
import "../../interfaces/IPacket.sol";
import "../../interfaces/IRouting.sol";
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
    IRouting public routing;
    IAccessManager public accessManager;

    mapping(bytes => uint64) public sequences;
    mapping(bytes => bytes32) public commitments;
    mapping(bytes => bool) public receipts;
    mapping(bytes => uint8) public ackStatus; // 0 => not found , 1 => success , 2 => err
    mapping(bytes => PacketTypes.Fee) public packetFees; // TBD: delete acked packet fee

    bytes32 public constant MULTISEND_ROLE = keccak256("MULTISEND_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /**
     * @notice initialize
     * @param clientManagerContract clientManager address
     * @param routingContract routing address
     * @param accessManagerContract accessManager address
     */
    function initialize(
        address clientManagerContract,
        address routingContract,
        address accessManagerContract
    ) public initializer {
        require(
            clientManagerContract != address(0) &&
                routingContract != address(0) &&
                accessManagerContract != address(0),
            "clientManager and routing and accessManager cannot be empty"
        );
        clientManager = IClientManager(clientManagerContract);
        routing = IRouting(routingContract);
        accessManager = IAccessManager(accessManagerContract);
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
     * @param packet xibc packet
     * @param fee packet fee
     */
    function sendPacket(
        PacketTypes.Packet memory packet,
        PacketTypes.Fee memory fee
    ) public payable override whenNotPaused {
        require(
            packet.dataList.length == 1 && packet.ports.length == 1,
            "should be one packet data"
        );
        require(packet.sequence > 0, "packet sequence cannot be 0");
        require(
            address(routing.getModule(packet.ports[0])) == _msgSender(),
            "module has not been registered to routing contract"
        );

        // Notice: must sent token to this contract before set packet fee
        packetFees[
            Host.ackStatusKey(
                packet.sourceChain,
                packet.destChain,
                packet.sequence
            )
        ] = fee;

        if (bytes(packet.relayChain).length > 0) {
            require(
                address(clientManager.getClient(packet.relayChain)) !=
                    address(0),
                "light client not found"
            );
        } else {
            require(
                address(clientManager.getClient(packet.destChain)) !=
                    address(0),
                "light client not found"
            );
        }
        bytes memory nextSequenceSendKey = Host.nextSequenceSendKey(
            packet.sourceChain,
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
        commitments[
            Host.packetCommitmentKey(
                packet.sourceChain,
                packet.destChain,
                packet.sequence
            )
        ] = sha256(
            Bytes.fromBytes32(
                sha256(Bytes.concat(bytes(packet.ports[0]), packet.dataList[0]))
            )
        );
        emit PacketSent(packet);
    }

    /**
     * @notice sendMultiPacket is called by a module in order to send an XIBC packet with multi data.
     * @param packet xibc packet
     * @param fee packet fee
     */
    function sendMultiPacket(
        PacketTypes.Packet memory packet,
        PacketTypes.Fee memory fee
    ) public payable override onlyAuthorizee(MULTISEND_ROLE) whenNotPaused {
        require(packet.sequence > 0, "packet sequence cannot be 0");
        require(
            packet.dataList.length == packet.ports.length &&
                packet.ports.length > 0,
            "invalid packet data or ports"
        );

        // Notice: must sent token to this contract before set packet fee
        packetFees[
            Host.ackStatusKey(
                packet.sourceChain,
                packet.destChain,
                packet.sequence
            )
        ] = fee;

        for (uint64 i = 0; i < packet.ports.length; i++) {
            require(
                packet.dataList[i].length > 0,
                "data bytes cannot be empty"
            );
        }

        if (bytes(packet.relayChain).length > 0) {
            require(
                address(clientManager.getClient(packet.relayChain)) !=
                    address(0),
                "light client not found"
            );
        } else {
            require(
                address(clientManager.getClient(packet.destChain)) !=
                    address(0),
                "light client not found"
            );
        }

        bytes memory nextSequenceSendKey = Host.nextSequenceSendKey(
            packet.sourceChain,
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

        bytes memory dataSum;
        for (uint64 i = 0; i < packet.ports.length; i++) {
            dataSum = Bytes.concat(
                dataSum,
                Bytes.fromBytes32(
                    sha256(
                        Bytes.concat(bytes(packet.ports[i]), packet.dataList[i])
                    )
                )
            );
        }

        commitments[
            Host.packetCommitmentKey(
                packet.sourceChain,
                packet.destChain,
                packet.sequence
            )
        ] = sha256(dataSum);

        emit PacketSent(packet);
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
        require(
            Strings.equals(packet.destChain, clientManager.getChainName()),
            "invalid destChain"
        );

        bytes memory packetReceiptKey = Host.packetReceiptKey(
            packet.sourceChain,
            packet.destChain,
            packet.sequence
        );

        require(!receipts[packetReceiptKey], "packet has been received");

        bytes memory dataSum;
        for (uint64 i = 0; i < packet.ports.length; i++) {
            dataSum = Bytes.concat(
                dataSum,
                Bytes.fromBytes32(
                    sha256(
                        Bytes.concat(bytes(packet.ports[i]), packet.dataList[i])
                    )
                )
            );
        }

        verifyPacketCommitment(
            _msgSender(),
            packet.sequence,
            packet.sourceChain,
            packet.destChain,
            packet.relayChain,
            proof,
            height,
            Bytes.fromBytes32(sha256(dataSum))
        );

        receipts[packetReceiptKey] = true;

        emit PacketReceived(packet);

        PacketTypes.Acknowledgement memory ack;
        try this.executePacket(packet) returns (bytes[] memory results) {
            ack.results = results;
        } catch Error(string memory message) {
            ack.message = message;
        }
        ack.relayer = msg.sender.addressToString();
        bytes memory ackBytes = abi.encode(ack);
        writeAcknowledgement(
            packet.sequence,
            packet.sourceChain,
            packet.destChain,
            packet.relayChain,
            ackBytes
        );
        emit AckWritten(packet, ackBytes);
    }

    /**
     * @notice executePacket ensures that every data is executed correctly
     * @param packet xibc packet
     */
    function executePacket(PacketTypes.Packet calldata packet)
        external
        onlySelf
        whenNotPaused
        returns (bytes[] memory)
    {
        bytes[] memory results = new bytes[](packet.ports.length);
        for (uint64 i = 0; i < packet.ports.length; i++) {
            IModule module = routing.getModule(packet.ports[i]);
            require(
                address(module) != address(0),
                Strings.strConcat(Strings.uint642str(i), ": module not found!")
            );
            PacketTypes.Result memory res = module.onRecvPacket(
                packet.dataList[i]
            );
            require(
                res.result.length > 0,
                Strings.strConcat(
                    Strings.strConcat(Strings.uint642str(i), ": "),
                    res.message
                )
            );
            results[i] = res.result;
        }
        return results;
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
    ) internal {
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
        require(
            Strings.equals(packet.sourceChain, clientManager.getChainName()),
            "invalid packet"
        );

        bytes memory dataSum;
        for (uint64 i = 0; i < packet.ports.length; i++) {
            dataSum = Bytes.concat(
                dataSum,
                Bytes.fromBytes32(
                    sha256(
                        Bytes.concat(bytes(packet.ports[i]), packet.dataList[i])
                    )
                )
            );
        }

        bytes memory packetCommitmentKey = Host.packetCommitmentKey(
            packet.sourceChain,
            packet.destChain,
            packet.sequence
        );

        require(
            commitments[packetCommitmentKey] == sha256(dataSum),
            "commitment bytes are not equal"
        );

        verifyPacketAcknowledgement(
            _msgSender(),
            packet.sequence,
            packet.sourceChain,
            packet.destChain,
            packet.relayChain,
            acknowledgement,
            proofAcked,
            height
        );

        delete commitments[packetCommitmentKey];

        setMaxAckSequence(
            packet.sourceChain,
            packet.destChain,
            packet.sequence
        );

        emit AckPacket(packet, acknowledgement);

        PacketTypes.Acknowledgement memory ack = abi.decode(
            acknowledgement,
            (PacketTypes.Acknowledgement)
        );

        if (ack.results.length > 0) {
            ackStatus[
                Host.ackStatusKey(
                    packet.sourceChain,
                    packet.destChain,
                    packet.sequence
                )
            ] = 1;
            for (uint64 i = 0; i < packet.ports.length; i++) {
                IModule module = routing.getModule(packet.ports[i]);
                module.onAcknowledgementPacket(
                    packet.dataList[i],
                    ack.results[i]
                );
            }
        } else {
            ackStatus[
                Host.ackStatusKey(
                    packet.sourceChain,
                    packet.destChain,
                    packet.sequence
                )
            ] = 2;
            for (uint64 i = 0; i < packet.ports.length; i++) {
                IModule module = routing.getModule(packet.ports[i]);
                module.onAcknowledgementPacket(packet.dataList[i], hex"");
            }
        }

        sendPacketFeeToRelayer(
            packet.sourceChain,
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
    ) internal {
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
