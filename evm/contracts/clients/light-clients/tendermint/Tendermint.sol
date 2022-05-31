// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "./Verifier.sol";
import "./LightClientLib.sol";
import "../../../interfaces/IClient.sol";
import "../../../libraries/utils/Bytes.sol";
import "../../../libraries/packet/Packet.sol";
import "../../../proto/Tendermint.sol";
import "../../../proto/Commitment.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Tendermint is Initializable, IClient, OwnableUpgradeable {
    struct SimpleHeader {
        uint64 revision_number;
        uint64 revision_height;
        uint64 timestamp;
        bytes32 root;
        bytes32 next_validators_hash;
    }

    // each version saves up to MAX_SIZE consensus states
    uint16 constant MAX_SIZE = 100;
    // current light client state
    ClientState.Data public clientState;
    // consensus states of light clients
    mapping(uint128 => ConsensusState.Data) private consensusStates;
    // system time each time the client status is updated
    mapping(uint128 => uint256) private processedTime;
    // clientManager contract address
    address clientManager;

    // check if caller is clientManager
    modifier onlyClientManager() {
        require(msg.sender == clientManager, "caller not client manager contract");
        _;
    }

    function initialize(address clientManagerAddr) public initializer {
        clientManager = clientManagerAddr;
    }

    /**
     * @notice returns the client type
     */
    function getClientType() external view override returns (IClient.Type) {
        return IClient.Type.Light;
    }

    /**
     * @notice returns the latest height of the current light client
     */
    function getLatestHeight() external view override returns (Height.Data memory) {
        return clientState.latest_height;
    }

    /**
     * @notice return the consensus status information of the specified height
     * @param height height of the consensus status
     */
    function getConsensusState(Height.Data memory height) public view returns (ConsensusState.Data memory) {
        uint128 key = getStorageKey(height);
        return consensusStates[key];
    }

    /**
     * @notice return the status of the current light client
     */
    function status() external view override returns (Status) {
        ConsensusState.Data storage consState = consensusStates[getStorageKey(clientState.latest_height)];
        if (consState.root.length == 0) {
            return Status.Unknown;
        }
        if (uint256(consState.timestamp.secs + clientState.trusting_period) <= block.timestamp) {
            return Status.Expired;
        }
        return Status.Active;
    }

    /**
     * @notice this function is called by the ClientManager contract, the purpose is to initialize light client state
     * @param clientStateBz light client status
     * @param consensusStateBz light client consensus status
     */
    function initializeState(bytes calldata clientStateBz, bytes calldata consensusStateBz)
        external
        override
        onlyClientManager
    {
        ClientStateCodec.decode(clientState, clientStateBz);
        uint128 key = getStorageKey(clientState.latest_height);
        consensusStates[key] = ConsensusStateCodec.decode(consensusStateBz);
        processedTime[key] = block.timestamp;
    }

    /**
     * @notice this function is called by the ClientManager contract, the purpose is to update the state of the light client
     * @param caller the msg.sender of manager contract
     * @param clientStateBz light client status
     * @param consensusStateBz light client consensus status
     */
    function upgrade(
        address caller,
        bytes calldata clientStateBz,
        bytes calldata consensusStateBz
    ) external override onlyClientManager {
        ClientStateCodec.decode(clientState, clientStateBz);

        uint128 key = getStorageKey(clientState.latest_height);
        consensusStates[key] = ConsensusStateCodec.decode(consensusStateBz);
        processedTime[key] = block.timestamp;
    }

    /**
     * @notice this function is called by the relayer, the purpose is to update and verify the state of the light client
     * @param caller the msg.sender of manager contract
     * @param headerBz block header of the counterparty chain
     */
    function checkHeaderAndUpdateState(address caller, bytes calldata headerBz) external override onlyClientManager {
        // SimpleHeader memory header = abi.decode(headerBz, (SimpleHeader));
        Header.Data memory header = HeaderCodec.decode(headerBz);

        ConsensusState.Data memory tmConsState = consensusStates[getStorageKey(header.trusted_height)];

        bytes memory vsh = LightClientGenValHash.genValidatorSetHash(header.trusted_validators);

        // check heaer
        require(Bytes.equals(vsh, tmConsState.next_validators_hash), "invalid validator set");
        require(
            uint64(header.signed_header.header.height) > header.trusted_height.revision_height,
            "invalid block height"
        );

        SignedHeader.Data memory trustedHeader;
        trustedHeader.header.chain_id = clientState.chain_id;
        trustedHeader.header.height = int64(clientState.latest_height.revision_height);
        trustedHeader.header.time = tmConsState.timestamp;
        trustedHeader.header.next_validators_hash = tmConsState.next_validators_hash;

        Timestamp.Data memory currentTimestamp;
        currentTimestamp.secs = int64(block.timestamp);

        // Verify next header with the passed-in trustedVals
        // - asserts trusting period not passed
        // - assert header timestamp is not past the trusting period
        // - assert header timestamp is past latest stored consensus state timestamp
        // - assert that a TrustLevel proportion of TrustedValidators signed new Commit
        LightClientVerify.verify(
            trustedHeader,
            header.trusted_validators,
            header.signed_header,
            header.validator_set,
            clientState.trusting_period,
            currentTimestamp,
            clientState.max_clock_drift,
            clientState.trust_level
        );

        // update the client state of the light client
        if (uint64(header.signed_header.header.height) > clientState.latest_height.revision_height) {
            clientState.latest_height.revision_height = uint64(header.signed_header.header.height);
        }

        // save the consensus state of the light client
        ConsensusState.Data memory newConsState;
        newConsState.timestamp = header.signed_header.header.time;
        newConsState.root = header.signed_header.header.app_hash;
        newConsState.next_validators_hash = header.signed_header.header.next_validators_hash;

        uint128 key = getStorageKey(
            Height.Data({
                revision_height: clientState.latest_height.revision_height,
                revision_number: clientState.latest_height.revision_number
            })
        );
        consensusStates[key] = newConsState;
        processedTime[key] = block.timestamp;
    }

    /**
     * @notice this function is called by the relayer, the purpose is to use the current state of the light client to verify cross-chain data packets
     * @param caller the msg.sender of manager contract
     * @param height the height of cross-chain data packet proof
     * @param proof proof of the existence of cross-chain data packets
     * @param srcChain the chain name of the source chain
     * @param dstChain the chain name of the destination chain
     * @param sequence the sequence of the cross-chain data packet
     * @param commitmentBytes the hash of the cross-chain data packet
     */
    function verifyPacketCommitment(
        address caller,
        Height.Data calldata height,
        bytes calldata proof,
        string calldata srcChain,
        string calldata dstChain,
        uint64 sequence,
        bytes calldata commitmentBytes
    ) external view override {
        uint128 key = getStorageKey(height);
        Verifier.verifyCommitment(
            clientState,
            consensusStates[key],
            processedTime[key],
            proof,
            srcChain,
            dstChain,
            sequence,
            commitmentBytes
        );
    }

    /**
     * @notice this function is called by the relayer, the purpose is to use the current state of the light client to verify the acknowledgement of cross-chain data packets
     * @param caller the msg.sender of manager contract
     * @param height the height of cross-chain data packet proof
     * @param proof proof of the existence of cross-chain data packets
     * @param srcChain the chain name of the source chain
     * @param dstChain the chain name of the destination chain
     * @param sequence the sequence of the cross-chain data packet
     * @param acknowledgement the hash of the acknowledgement of the cross-chain data packet
     */
    function verifyPacketAcknowledgement(
        address caller,
        Height.Data calldata height,
        bytes calldata proof,
        string calldata srcChain,
        string calldata dstChain,
        uint64 sequence,
        bytes calldata acknowledgement
    ) external view override {
        uint128 key = getStorageKey(height);
        Verifier.verifyAcknowledgement(
            clientState,
            consensusStates[key],
            processedTime[key],
            proof,
            srcChain,
            dstChain,
            sequence,
            acknowledgement
        );
    }

    function getStorageKey(Height.Data memory data) private pure returns (uint128 ret) {
        ret = data.revision_number;
        ret = (ret << 64);
        ret |= (data.revision_height % MAX_SIZE);
    }
}
