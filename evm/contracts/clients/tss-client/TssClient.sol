pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../../libraries/packet/Packet.sol";
import "../../libraries/utils/Bytes.sol";
import "../../interfaces/IClient.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract TssClient is Initializable, IClient, OwnableUpgradeable {
    struct ClientState {
        address tss_address;
        bytes pubkey;
        bytes[] part_pubkeys;
    }

    struct Header {
        bytes pubkey;
        bytes[] part_pubkeys;
    }

    // current client state
    ClientState public clientState;

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

    function getClientState() public view returns (ClientState memory) {
        return clientState;
    }

    /**
     * @notice returns the client type
     */
    function getClientType() external view override returns (IClient.Type) {
        return IClient.Type.TSS;
    }

    /**
     * @notice returns the latest height of the current TSS client
     */
    function getLatestHeight() external view override returns (Height.Data memory) {
        return Height.Data(0, 0);
    }

    /**
     * @notice return the status of the current TSS client
     */
    function status() external view override returns (Status) {
        return Status.Active;
    }

    /**
     * @notice this function is called by the ClientManager contract, the purpose is to initialize TSS client state
     * @param clientStateBz TSS client status
     * @param consensusStateBz TSS client consensus status
     */
    function initializeState(bytes calldata clientStateBz, bytes calldata consensusStateBz)
        external
        override
        onlyClientManager
    {
        clientState = abi.decode(clientStateBz, (ClientState));
        clientState.tss_address = address(uint160(uint256(keccak256(clientState.pubkey))));
    }

    /**
     * @notice this function is called by the ClientManager contract, the purpose is to update the state of the TSS client
     * @param clientStateBz TSS client status
     * @param consensusStateBz TSS client consensus status
     */
    function upgrade(
        address caller,
        bytes calldata clientStateBz,
        bytes calldata consensusStateBz
    ) external override onlyClientManager {
        // Authorize to tss address in the future
        // require(
        //     caller == clientState.tss_address,
        //     "caller must be the tss address"
        // );
        clientState = abi.decode(clientStateBz, (ClientState));
        clientState.tss_address = address(uint160(uint256(keccak256(clientState.pubkey))));
    }

    /**
     * @notice this function is called by the relayer, the purpose is to update and verify the state of the TSS client
     * @param headerBz block header of the counterparty chain
     */
    function checkHeaderAndUpdateState(address caller, bytes calldata headerBz) external override onlyClientManager {
        // Authorize to tss address in the future
        // require(
        //     caller == clientState.tss_address,
        //     "caller must be the tss address"
        // );
        Header memory header = abi.decode(headerBz, (Header));
        clientState.pubkey = header.pubkey;
        clientState.tss_address = address(uint160(uint256(keccak256(header.pubkey))));
        clientState.part_pubkeys = header.part_pubkeys;
    }

    /**
     * @notice this function is called by the relayer, the purpose is to use the current state of the TSS client to verify cross-chain data packets
     * @param caller the msg.sender of manager contract
     * @param height the height of cross-chain data packet proof
     * @param proof proof of the existence of cross-chain data packets
     * @param sourceChain the chain name of the source chain
     * @param destChain the chain name of the destination chain
     * @param sequence the sequence of the cross-chain data packet
     * @param commitmentBytes the hash of the cross-chain data packet
     */
    function verifyPacketCommitment(
        address caller,
        Height.Data calldata height,
        bytes calldata proof,
        string calldata sourceChain,
        string calldata destChain,
        uint64 sequence,
        bytes calldata commitmentBytes
    ) external view override {
        require(caller == clientState.tss_address, "caller must be the tss address");
    }

    /**
     * @notice this function is called by the relayer, the purpose is to use the current state of the TSS client to verify the acknowledgement of cross-chain data packets
     * @param caller the msg.sender of manager contract
     * @param height the height of cross-chain data packet proof
     * @param proof proof of the existence of cross-chain data packets
     * @param sourceChain the chain name of the source chain
     * @param destChain the chain name of the destination chain
     * @param sequence the sequence of the cross-chain data packet
     * @param acknowledgement the hash of the acknowledgement of the cross-chain data packet
     */
    function verifyPacketAcknowledgement(
        address caller,
        Height.Data calldata height,
        bytes calldata proof,
        string calldata sourceChain,
        string calldata destChain,
        uint64 sequence,
        bytes calldata acknowledgement
    ) external view override {
        require(caller == clientState.tss_address, "caller must be the tss address");
    }
}
