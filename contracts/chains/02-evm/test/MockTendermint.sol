// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import "../../../libraries/packet/Packet.sol";
import "../../../interfaces/IClient.sol";
import "../../../libraries/utils/Bytes.sol";
import "../../../libraries/tendermint/LightClient.sol";
import "../../../proto/Tendermint.sol";
import "../../../proto/Commitment.sol";
import "../clients/light-clients/tendermint/Verifier.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MockTendermint is Initializable, IClient, OwnableUpgradeable {
    struct SimpleHeader {
        uint64 revision_number;
        uint64 revision_height;
        uint64 timestamp;
        bytes32 root;
        bytes32 next_validators_hash;
    }

    // each version saves up to MAX_SIZE consensus states
    uint16 constant MAX_SIZE = 100;
    // current light client status
    ClientState.Data public clientState;
    // consensus status of light clients
    mapping(uint128 => ConsensusState.Data) private consensusStates;
    // system time each time the client status is updated
    mapping(uint128 => uint256) private processedTime;

    function initialize(address clientManagerAddr) public initializer {
        __Ownable_init();
        transferOwnership(clientManagerAddr);
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

        if (!(uint256(uint64(consState.timestamp.secs + clientState.trusting_period)) > block.timestamp)) {
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
        onlyOwner
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
    ) external override onlyOwner {
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
    function checkHeaderAndUpdateState(address caller, bytes calldata headerBz) external override onlyOwner {
        SimpleHeader memory header = abi.decode(headerBz, (SimpleHeader));
        //revision_number must be consistent
        require(clientState.latest_height.revision_number == header.revision_number, "RevisionNumber not match");

        // update the client state of the light client
        if (header.revision_height > clientState.latest_height.revision_height) {
            clientState.latest_height.revision_height = header.revision_height;
        }

        // save the consensus state of the light client
        ConsensusState.Data memory newConsState;
        newConsState.timestamp = Timestamp.Data({secs: int64(header.timestamp), nanos: 0});
        newConsState.root = Bytes.fromBytes32(header.root);
        newConsState.next_validators_hash = Bytes.fromBytes32(header.next_validators_hash);

        uint128 key = getStorageKey(
            Height.Data({revision_height: header.revision_height, revision_number: header.revision_number})
        );
        consensusStates[key] = newConsState;
        processedTime[key] = block.timestamp;
    }

    /**
     * @notice this function is called by the relayer, the purpose is to use the current state of the light client to verify cross-chain data packets
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
    ) external view override {}

    /**
     * @notice this function is called by the relayer, the purpose is to use the current state of the light client to verify the acknowledgement of cross-chain data packets
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
    ) external view override {}

    function getStorageKey(Height.Data memory data) private pure returns (uint128 ret) {
        ret = data.revision_number;
        ret = (ret << 64);
        ret |= (data.revision_height % MAX_SIZE);
    }
}
