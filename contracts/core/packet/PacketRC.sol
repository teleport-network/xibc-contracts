// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.12;

import "../../libraries/utils/Bytes.sol";
import "../../libraries/utils/Strings.sol";
import "../../interfaces/IClientManager.sol";
import "../../interfaces/IClient.sol";
import "../../interfaces/IPacket.sol";
import "../../interfaces/IEndpoint.sol";
import "../../interfaces/IAccessManager.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

interface IExecute {
    /**
     * @notice execute a caontract call
     * @param callData contract call data
     */
    function execute(PacketTypes.CallData calldata callData) external returns (bool success, bytes memory res);
}

contract PacketRC is
    Initializable,
    OwnableUpgradeable,
    IPacket,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    LatestPacket
{
    using Strings for *;
    using Bytes for *;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant FEE_MANAGER = keccak256("FEE_MANAGER");

    string public override chainName;

    IClientManagerRC public clientManager;
    IAccessManager public accessManager;
    IEndpoint public endpoint;
    IExecute public execute;

    // key: bytes(dstChain)
    mapping(bytes => uint64) public sequences;
    // packetCommitmentKey: bytes(commitments/$srcChain/$destChain/sequences/$sequence)
    // packetAcknowledgementKey: bytes(acks/$srcChain/$destChain/sequences/$sequence)
    mapping(bytes => bytes32) public commitments;
    // key: bytes($srcChain/$seqence)
    mapping(bytes => bool) public receipts;
    // key: bytes($dstChain/$seqence)
    // ack state(1 => success, 2 => err, 0 => not found)
    mapping(bytes => uint8) public ackStatus;
    // key: bytes($dstChain/$seqence)
    mapping(bytes => PacketTypes.Acknowledgement) public acks;
    // key: bytes($dstChain/$seqence)
    // TBD: delete acked packet fee
    mapping(bytes => PacketTypes.Fee) public packetFees;

    // latest packet, only will be saved on relay chain
    PacketTypes.Packet public latestPacket;

    /**
     * @notice initialize
     * @param _chainName chain name
     * @param _clientManagerContract clientManager address
     * @param _accessManagerContract accessManager address
     */
    function initialize(
        string memory _chainName,
        address _clientManagerContract,
        address _accessManagerContract
    ) public initializer {
        require(
            bytes(_chainName).length > 0 &&
                _clientManagerContract != address(0) &&
                _accessManagerContract != address(0),
            "invalid chainName, relayChainName, clientManagerContract or accessManager"
        );
        chainName = _chainName;
        clientManager = IClientManagerRC(_clientManagerContract);
        accessManager = IAccessManager(_accessManagerContract);
    }

    /**
     * @notice initialize endpoint contract
     * @param _endpointContract endpointContract address
     */
    function initEndpoint(address _endpointContract, address _executeContract)
        public
        onlyAuthorizee(DEFAULT_ADMIN_ROLE)
    {
        require(
            _endpointContract != address(0) && _executeContract != address(0),
            "invalid endpointContract or executeContract address"
        );
        endpoint = IEndpoint(_endpointContract);
        execute = IExecute(_executeContract);
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
     * @param feeToken fee token
     * @param feeAmount fee amount
     */
    event AckPacket(PacketTypes.Packet packet, bytes ack, address feeToken, uint256 feeAmount);

    /**
     * @notice Event triggered when receive ack
     * @param packet packet data
     * @param ack ack bytes
     */
    event AckWritten(PacketTypes.Packet packet, bytes ack);

    // only Endpoint contract can perform related transactions
    modifier onlyEndpointContract() {
        require(address(endpoint) == _msgSender(), "only endpoint contract authorized");
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
    function sendPacket(PacketTypes.Packet memory packet, PacketTypes.Fee memory fee)
        public
        payable
        override
        whenNotPaused
        onlyEndpointContract
    {
        require(address(clientManager.clients(packet.dstChain)) != address(0), "invalid client");
        require(packet.sequence > 0, "packet sequence cannot be 0");
        require(packet.srcChain.equals(chainName), "srcChain mismatch");
        require(!packet.dstChain.equals(chainName), "invalid dstChain");

        // Notice: must sent token to this contract before set packet fee
        packetFees[commonUniqueKey(packet.dstChain, packet.sequence)] = fee;

        bytes memory nextSequenceSendKey = bytes(packet.dstChain);
        if (sequences[nextSequenceSendKey] == 0) {
            sequences[nextSequenceSendKey] = 1;
        }

        require(packet.sequence == sequences[nextSequenceSendKey], "packet sequence != next send sequence");
        sequences[nextSequenceSendKey]++;

        bytes memory bz = abi.encode(packet);
        commitments[packetCommitmentKey(packet.srcChain, packet.dstChain, packet.sequence)] = sha256(bz);
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
    ) external nonReentrant whenNotPaused {
        require(clientManager.authRelayer(msg.sender), "not authorized");
        PacketTypes.Packet memory packet = abi.decode(packetBytes, (PacketTypes.Packet));
        bytes memory packetReceiptKey = commonUniqueKey(packet.srcChain, packet.sequence);
        require(!receipts[packetReceiptKey], "packet has been received");
        bytes memory packetCommitment = Bytes.fromBytes32(sha256(packetBytes));
        _verifyPacketCommitment(
            _msgSender(),
            packet.sequence,
            packet.srcChain,
            packet.dstChain,
            proof,
            height,
            packetCommitment
        );
        receipts[packetReceiptKey] = true;
        emit PacketReceived(packet);

        PacketTypes.Acknowledgement memory ack;
        ack.relayer = clientManager.getRelayerChainAddress(msg.sender, packet.srcChain);
        if (!packet.dstChain.equals(chainName)) {
            // two hops packet, do not excute
            if (address(clientManager.clients(packet.dstChain)) != address(0)) {
                ack.code = 1;
                ack.message = "dst client not exist";
                _writeAcknowledgement(packet, ack);
                return;
            }
            // save packet commitment and emit packet sent event
            commitments[packetCommitmentKey(packet.srcChain, packet.dstChain, packet.sequence)] = sha256(packetBytes);
            emit PacketSent(packetBytes);
            return;
        }

        ack.feeOption = packet.feeOption;
        if (packet.transferData.length == 0 && packet.callData.length == 0) {
            ack.code = 1;
            ack.message = "empty pcaket data";
            _writeAcknowledgement(packet, ack);
            return;
        }
        if (packet.transferData.length > 0) {
            try endpoint.onRecvPacket(packet) returns (uint64 _code, bytes memory _result, string memory _message) {
                ack.code = _code;
                ack.result = _result;
                ack.message = _message;
                if (_code != 0) {
                    _writeAcknowledgement(packet, ack);
                    return;
                }
            } catch {
                ack.code = 2;
                ack.message = "execute transfer data failed";
                _writeAcknowledgement(packet, ack);
                return;
            }
        }
        if (packet.callData.length > 0) {
            PacketTypes.CallData memory callData = abi.decode(packet.callData, (PacketTypes.CallData));
            (bool success, bytes memory res) = execute.execute(callData);
            if (!success) {
                ack.code = 2;
                ack.message = "execute call data failed";
                _writeAcknowledgement(packet, ack);
                return;
            }
            ack.result = res;
            _writeAcknowledgement(packet, ack);
            return;
        }
        _writeAcknowledgement(packet, ack);
        return;
    }

    /**
     * @notice Verify packet commitment
     */
    function _verifyPacketCommitment(
        address sender,
        uint64 sequence,
        string memory srcChain,
        string memory dstChain,
        bytes memory proof,
        Height.Data memory height,
        bytes memory commitBytes
    ) private view {
        clientManager.clients(srcChain).verifyPacketCommitment(
            sender,
            height,
            proof,
            srcChain,
            dstChain,
            sequence,
            commitBytes
        );
    }

    /**
     * @notice _writeAcknowledgement is called by a module in order to send back a ack message
     * @param packet xibc packet
     * @param ack acknowledgement to write
     */
    function _writeAcknowledgement(PacketTypes.Packet memory packet, PacketTypes.Acknowledgement memory ack) private {
        bytes memory ackBytes = abi.encode(ack);
        bytes memory pktAckKey = packetAcknowledgementKey(packet.srcChain, packet.dstChain, packet.sequence);
        require(commitments[pktAckKey] == bytes32(0), "acknowledgement for packet already exists");
        require(ackBytes.length != 0, "acknowledgement cannot be empty");
        commitments[pktAckKey] = sha256(ackBytes);
        emit AckWritten(packet, ackBytes);
    }

    /**
     * @notice acknowledgePacket is called by relayer in order to receive an XIBC acknowledgement
     * @param packetBytes xibc packet bytes
     * @param acknowledgement acknowledgement from dst chain
     * @param proofAcked ack proof commit
     * @param height ack proof height
     */
    function acknowledgePacket(
        bytes calldata packetBytes,
        bytes calldata acknowledgement,
        bytes calldata proofAcked,
        Height.Data calldata height
    ) external nonReentrant whenNotPaused {
        PacketTypes.Packet memory packet = abi.decode(packetBytes, (PacketTypes.Packet));
        require(address(clientManager.clients(packet.dstChain)) != address(0), "invalid dst client");
        _verifyPacketAcknowledgement(
            _msgSender(),
            packet.sequence,
            packet.srcChain,
            packet.dstChain,
            acknowledgement,
            proofAcked,
            height
        );

        // save packet ack commitment
        bytes memory pktCmtKey = packetCommitmentKey(packet.srcChain, packet.dstChain, packet.sequence);
        require(commitments[pktCmtKey] == sha256(packetBytes), "commitment bytes are not equal");
        delete commitments[pktCmtKey];
        PacketTypes.Fee memory fee = packetFees[commonUniqueKey(packet.dstChain, packet.sequence)];
        emit AckPacket(packet, acknowledgement, fee.tokenAddress, fee.amount);

        // check is two hops ack or not on relay chain
        if (!packet.srcChain.equals(chainName)) {
            // write ack commitment
            bytes memory pktAckKey = packetAcknowledgementKey(packet.srcChain, packet.dstChain, packet.sequence);
            require(commitments[pktAckKey] == bytes32(0), "acknowledgement for packet already exists");
            require(acknowledgement.length != 0, "acknowledgement cannot be empty");
            commitments[pktAckKey] = sha256(acknowledgement);
            emit AckWritten(packet, acknowledgement);
            return;
        }

        // update ack status and excute packet ack
        PacketTypes.Acknowledgement memory ack = abi.decode(acknowledgement, (PacketTypes.Acknowledgement));
        bytes memory key = commonUniqueKey(packet.dstChain, packet.sequence);
        if (ack.code == 0) {
            ackStatus[key] = 1;
        } else {
            ackStatus[key] = 2;
        }
        acks[key] = ack;
        endpoint.onAcknowledgementPacket(packet, ack.code, ack.result, ack.message);
        if (!packet.dstChain.equals(chainName)) {
            _sendPacketFeeToRelayer(packet.dstChain, packet.sequence, ack.relayer.parseAddr());
        }
    }

    /**
     * @notice send packet fee to relayer
     * @param dstChain destination chain name
     * @param sequence sequence
     * @param relayer relayer address
     */
    function _sendPacketFeeToRelayer(
        string memory dstChain,
        uint64 sequence,
        address relayer
    ) private {
        PacketTypes.Fee memory fee = packetFees[commonUniqueKey(dstChain, sequence)];
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
        string memory srcChain,
        string memory dstChain,
        bytes memory acknowledgement,
        bytes memory proofAcked,
        Height.Data memory height
    ) private view {
        clientManager.clients(dstChain).verifyPacketAcknowledgement(
            sender,
            height,
            proofAcked,
            srcChain,
            dstChain,
            sequence,
            Bytes.fromBytes32(sha256(acknowledgement))
        );
    }

    /**
     * @notice get packet next sequence to send
     * @param dstChain name of destination chain
     * @return returns next sequence
     */
    function getNextSequenceSend(string memory dstChain) public view override returns (uint64) {
        uint64 seq = sequences[bytes(dstChain)];
        if (seq == 0) {
            seq = 1;
        }
        return seq;
    }

    /**
     * @notice get the next sequence of dstChain
     * @param dstChain destination chain name
     * @param sequence sequence
     * @return returns the acknowledgement status
     */
    function getAckStatus(string calldata dstChain, uint64 sequence) external view override returns (uint8) {
        return ackStatus[commonUniqueKey(dstChain, sequence)];
    }

    /**
     * @notice set packet fee
     * @param dstChain destination chain name
     * @param sequence sequence
     * @param amount add fee amount
     */
    function addPacketFee(
        string memory dstChain,
        uint64 sequence,
        uint256 amount
    ) public payable whenNotPaused {
        bytes memory key = commonUniqueKey(dstChain, sequence);
        require(ackStatus[key] == uint8(0), "invalid packet status");
        PacketTypes.Fee memory fee = packetFees[key];
        if (fee.tokenAddress == address(0)) {
            require(msg.value > 0 && msg.value == amount, "invalid value");
        } else {
            require(msg.value == 0, "invalid value");
            require(IERC20(fee.tokenAddress).transferFrom(msg.sender, address(this), amount), "transfer ERC20 failed");
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

    /**
     * @notice commonUniqueKey defines the key for the common unique key
     *  @param chain chain name
     *  @param sequence sequence
     */
    function commonUniqueKey(string memory chain, uint64 sequence) internal pure returns (bytes memory) {
        return bytes(string.concat(chain, "/", Strings.uint642str(sequence)));
    }

    /**
     * @notice packetCommitmentKey defines the next send sequence counter store key
     *  @param srcChain source chain name
     *  @param dstChain destination chain name
     *  @param sequence sequence
     */
    function packetCommitmentKey(
        string memory srcChain,
        string memory dstChain,
        uint64 sequence
    ) internal pure returns (bytes memory) {
        return
            bytes(string.concat("commitments/", srcChain, "/", dstChain, "/sequences/", Strings.uint642str(sequence)));
    }

    /**
     * @notice packetAcknowledgementKey defines the packet acknowledgement store key
     * @param srcChain source chain name
     * @param dstChain destination chain name
     * @param sequence sequence
     */
    function packetAcknowledgementKey(
        string memory srcChain,
        string memory dstChain,
        uint64 sequence
    ) internal pure returns (bytes memory) {
        return bytes(string.concat("acks/", srcChain, "/", dstChain, "/sequences/", Strings.uint642str(sequence)));
    }

    /**
     * @notice get latest packet
     * @return returns latest packet
     */
    function getLatestPacket() external view override returns (PacketTypes.Packet memory) {
        return latestPacket;
    }
}
