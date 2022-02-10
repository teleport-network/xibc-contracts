// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../interfaces/IClientManager.sol";
import "../interfaces/IClient.sol";
import "../interfaces/IAccessManager.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

contract MockClientManager is
    Initializable,
    OwnableUpgradeable,
    IClientManager
{
    // the name of this chain cannot be changed once initialized
    string private nativeChainName;
    // client currently registered in this chain
    mapping(string => IClient) public clients;
    // relayer registered by each client
    mapping(string => mapping(address => bool)) public relayers;
    // access control contract
    IAccessManager public accessManager;

    bytes32 public constant CREATE_CLIENT_ROLE =
        keccak256("CREATE_CLIENT_ROLE");
    bytes32 public constant UPGRADE_CLIENT_ROLE =
        keccak256("UPGRADE_CLIENT_ROLE");
    bytes32 public constant REGISTER_RELAYER_ROLE =
        keccak256("REGISTER_RELAYER_ROLE");

    uint256 public version;

    // only authorized accounts can perform related transactions
    modifier onlyAuthorizee(bytes32 role) {
        require(accessManager.hasRole(role, _msgSender()), "not authorized");
        _;
    }

    // check if caller is relayer
    modifier onlyRelayer(string memory chainName) {
        require(relayers[chainName][msg.sender], "caller not register");
        _;
    }

    function initialize(string memory name, address accessManagerContract)
        public
        initializer
    {
        nativeChainName = name;
        accessManager = IAccessManager(accessManagerContract);
    }

    function setVersion(uint256 _version) public {
        version = _version;
    }

    /**
     *  @notice this function is intended to be called by owner to create a client and initialize client data.
     *  @param chainName        the counterparty chain name
     *  @param clientAddress    client contract address
     *  @param clientState      client status
     *  @param consensusState   client consensus status
     */
    function createClient(
        string calldata chainName,
        address clientAddress,
        bytes calldata clientState,
        bytes calldata consensusState
    ) external onlyAuthorizee(CREATE_CLIENT_ROLE) {
        require(
            address(clients[chainName]) == address(0x0),
            "chainName already exist"
        );
        require(
            clientAddress != address(0x0),
            "clientAddress can not be empty"
        );

        IClient client = IClient(clientAddress);
        client.initializeState(clientState, consensusState);
        clients[chainName] = client;
    }

    /**
     *  @notice this function is called by the relayer, the purpose is to update the state of the client
     *  @param chainName  the counterparty chain name
     *  @param header     block header of the counterparty chain
     */
    function updateClient(string calldata chainName, bytes calldata header)
        external
        onlyRelayer(chainName)
    {
        IClient client = clients[chainName];
        require(client.status() == IClient.Status.Active, "client not active");
        client.checkHeaderAndUpdateState(_msgSender(), header);
    }

    /**
     *  @notice this function is called by the owner, the purpose is to update the state of the client
     *  @param chainName        the counterparty chain name
     *  @param clientState      client status
     *  @param consensusState   client consensus status
     */
    function upgradeClient(
        string calldata chainName,
        bytes calldata clientState,
        bytes calldata consensusState
    ) external onlyAuthorizee(UPGRADE_CLIENT_ROLE) {
        IClient client = clients[chainName];
        client.upgrade(_msgSender(), clientState, consensusState);
    }

    /**
     *  @notice this function is called by the owner, the purpose is to toggle client type between Light and TSS
     *  @param chainName        the counterparty chain name
     *  @param clientAddress    client contract address
     *  @param clientState      client status
     *  @param consensusState   client consensus status
     */
    function toggleClient(
        string calldata chainName,
        address clientAddress,
        bytes calldata clientState,
        bytes calldata consensusState
    ) external onlyAuthorizee(UPGRADE_CLIENT_ROLE) {
        require(
            clients[chainName].status() == IClient.Status.Active,
            "client not active"
        );
        require(
            IClient(clientAddress).getClientType() !=
                clients[chainName].getClientType(),
            "could not be the same"
        );
        IClient client = IClient(clientAddress);
        client.initializeState(clientState, consensusState);
        clients[chainName] = client;
    }

    /**
     *  @notice this function is called by the owner, the purpose is to register the relayer address of a client
     *  @param chainName  the counterparty chain name
     *  @param relayer    relayer address
     */
    function registerRelayer(string calldata chainName, address relayer)
        external
        onlyAuthorizee(REGISTER_RELAYER_ROLE)
    {
        require(!relayers[chainName][relayer], "relayer already registered");
        relayers[chainName][relayer] = true;
    }

    /**
     *  @notice obtain the contract address of the client according to the registered client name
     *  @param chainName  the counterparty chain name
     */
    function getClient(string memory chainName)
        public
        override
        returns (IClient)
    {
        return clients[chainName];
    }

    /**
     *  @notice obtain the contract address of the client according to the registered client name
     *  @param chainName  the counterparty chain name
     */
    function getClientType(string memory chainName)
        public
        override
        returns (IClient.Type)
    {
        return clients[chainName].getClientType();
    }

    /**
     *  @notice get the name of this chain
     */
    function getChainName() external view override returns (string memory) {
        return nativeChainName;
    }

    /**
     *  @notice get the latest height of the specified client update
     *  @param chainName  the counterparty chain name
     */
    function getLatestHeight(string memory chainName)
        public
        view
        override
        returns (Height.Data memory)
    {
        return (clients[chainName]).getLatestHeight();
    }
}
