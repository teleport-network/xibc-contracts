// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "../../../../interfaces/IClientManager.sol";
import "../../../../interfaces/IClient.sol";
import "../../../../interfaces/IAccessManager.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract ClientManager is Initializable, OwnableUpgradeable, IClientManager {
    // relay chain client
    IClient public override client;
    // access control contract
    IAccessManager public accessManager;

    bytes32 public constant CREATE_CLIENT_ROLE = keccak256("CREATE_CLIENT_ROLE");
    bytes32 public constant UPGRADE_CLIENT_ROLE = keccak256("UPGRADE_CLIENT_ROLE");
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");

    // only authorized accounts can perform related transactions
    modifier onlyAuthorizee(bytes32 role) {
        require(accessManager.hasRole(role, _msgSender()), "not authorized");
        _;
    }

    /**
     * @notice todo
     */
    function initialize(address accessManagerContract) public initializer {
        accessManager = IAccessManager(accessManagerContract);
    }

    /**
     *  @notice this function is intended to be called by owner to create a client and initialize client data.
     *  @param clientAddress    client contract address
     *  @param clientState      client status
     *  @param consensusState   client consensus status
     */
    function createClient(
        address clientAddress,
        bytes calldata clientState,
        bytes calldata consensusState
    ) external onlyAuthorizee(CREATE_CLIENT_ROLE) {
        require(address(client) == address(0x0), "client already exist");
        require(clientAddress != address(0x0), "clientAddress can not be empty");
        client = IClient(clientAddress);
        client.initializeState(clientState, consensusState);
    }

    /**
     *  @notice this function is called by the relayer, the purpose is to update the state of the client
     *  @param header     block header of the counterparty chain
     */
    function updateClient(bytes calldata header) external onlyAuthorizee(RELAYER_ROLE) {
        require(client.status() == IClient.Status.Active, "client not active");
        client.checkHeaderAndUpdateState(_msgSender(), header);
    }

    /**
     *  @notice this function is called by the owner, the purpose is to update the state of the client
     *  @param clientState      client status
     *  @param consensusState   client consensus status
     */
    function upgradeClient(bytes calldata clientState, bytes calldata consensusState)
        external
        onlyAuthorizee(UPGRADE_CLIENT_ROLE)
    {
        client.upgrade(_msgSender(), clientState, consensusState);
    }

    /**
     *  @notice this function is called by the owner, the purpose is to toggle client type between Light and TSS
     *  @param clientAddress    client contract address
     *  @param clientState      client status
     *  @param consensusState   client consensus status
     */
    function toggleClient(
        address clientAddress,
        bytes calldata clientState,
        bytes calldata consensusState
    ) external onlyAuthorizee(UPGRADE_CLIENT_ROLE) {
        require(IClient(clientAddress).getClientType() != client.getClientType(), "could not be the same");
        client = IClient(clientAddress);
        client.initializeState(clientState, consensusState);
    }

    /**
     *  @notice obtain the contract address of the client
     */
    function getClientType() public view override returns (IClient.Type) {
        return client.getClientType();
    }

    /**
     *  @notice get the latest height of the client update
     */
    function getLatestHeight() public view override returns (Height.Data memory) {
        return client.getLatestHeight();
    }
}
