// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import "../../libraries/packet/Packet.sol";
import "../../libraries/utils/Bytes.sol";
import "../../interfaces/IClient.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract TssClient is Initializable, IClient, OwnableUpgradeable {
    struct ClientState {
        address tss_address;
        bytes pubkey;
        bytes[] part_pubkeys;
        uint64 threshold;
    }

    struct Header {
        bytes pubkey;
        bytes[] part_pubkeys;
        uint64 threshold;
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
     */
    function initializeState(bytes calldata clientStateBz, bytes calldata) external override onlyClientManager {
        clientState = abi.decode(clientStateBz, (ClientState));
        clientState.tss_address = address(uint160(uint256(keccak256(clientState.pubkey))));
    }

    /**
     * @notice this function is called by the ClientManager contract, the purpose is to update the state of the TSS client
     * @param clientStateBz TSS client status
     */
    function upgrade(
        address,
        bytes calldata clientStateBz,
        bytes calldata
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
    function checkHeaderAndUpdateState(address, bytes calldata headerBz) external override onlyClientManager {
        // Authorize to tss address in the future
        // require(
        //     caller == clientState.tss_address,
        //     "caller must be the tss address"
        // );
        Header memory header = abi.decode(headerBz, (Header));
        clientState.pubkey = header.pubkey;
        clientState.tss_address = address(uint160(uint256(keccak256(header.pubkey))));
        clientState.part_pubkeys = header.part_pubkeys;
        clientState.threshold = header.threshold;
    }

    /**
     * @notice this function is called by the relayer, the purpose is to use the current state of the TSS client to verify cross-chain data packets
     * @param caller the msg.sender of manager contract
     */
    function verifyPacketCommitment(
        address caller,
        Height.Data calldata,
        bytes calldata,
        string calldata,
        string calldata,
        uint64,
        bytes calldata
    ) external view override {
        require(caller == clientState.tss_address, "caller must be the tss address");
    }

    /**
     * @notice this function is called by the relayer, the purpose is to use the current state of the TSS client to verify the acknowledgement of cross-chain data packets
     * @param caller the msg.sender of manager contract
     */
    function verifyPacketAcknowledgement(
        address caller,
        Height.Data calldata,
        bytes calldata,
        string calldata,
        string calldata,
        uint64,
        bytes calldata
    ) external view override {
        require(caller == clientState.tss_address, "caller must be the tss address");
    }
}
