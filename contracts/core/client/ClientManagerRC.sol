// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import "../../libraries/utils/Strings.sol";
import "../../interfaces/IClientManager.sol";
import "../../interfaces/IClient.sol";
import "../../interfaces/IAccessManager.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract ClientManagerRC is Initializable, OwnableUpgradeable, IClientManagerRC {
    using Strings for *;

    // relay chain client
    mapping(string => IClient) public override clients;
    // access control contract
    IAccessManager public accessManager;

    struct Relayer {
        address addr;
        string[] chains;
        string[] chainAddrs;
    }

    Relayer[] public relayers;

    bytes32 public constant CREATE_CLIENT_ROLE = keccak256("CREATE_CLIENT_ROLE");
    bytes32 public constant UPGRADE_CLIENT_ROLE = keccak256("UPGRADE_CLIENT_ROLE");
    bytes32 public constant REGISTER_RELAYER_ROLE = keccak256("REGISTER_RELAYER_ROLE");

    // only authorized accounts can perform related transactions
    modifier onlyAuthorizee(bytes32 role) {
        require(accessManager.hasRole(role, _msgSender()), "not authorized");
        _;
    }

    /**
     * @notice initialize contract address
     *  @param accessManagerContract accessManager contract address
     */
    function initialize(address accessManagerContract) public initializer {
        accessManager = IAccessManager(accessManagerContract);
    }

    /**
     *  @notice this function is intended to be called by owner to create a client and initialize client data.
     *  @param chain client chain name
     *  @param clientAddress client contract address
     *  @param clientState client status
     *  @param consensusState client consensus status
     */
    function createClient(
        string calldata chain,
        address clientAddress,
        bytes calldata clientState,
        bytes calldata consensusState
    ) external onlyAuthorizee(CREATE_CLIENT_ROLE) {
        require(address(clients[chain]) == address(0x0), "client already exist");
        require(clientAddress != address(0x0), "clientAddress can not be empty");
        clients[chain] = IClient(clientAddress);
        clients[chain].initializeState(clientState, consensusState);
    }

    /**
     *  @notice this function is called by the relayer, the purpose is to update the state of the client
     *  @param chain client chain name
     *  @param header block header of the counterparty chain
     */
    function updateClient(string calldata chain, bytes calldata header) external {
        require(authRelayer(msg.sender), "sned is not registerd relayer");
        require(clients[chain].status() == IClient.Status.Active, "client not active");
        clients[chain].checkHeaderAndUpdateState(_msgSender(), header);
    }

    /**
     *  @notice this function is called by the owner, the purpose is to update the state of the client
     *  @param chain client chain name
     *  @param clientState client status
     *  @param consensusState client consensus status
     */
    function upgradeClient(
        string calldata chain,
        bytes calldata clientState,
        bytes calldata consensusState
    ) external onlyAuthorizee(UPGRADE_CLIENT_ROLE) {
        clients[chain].upgrade(_msgSender(), clientState, consensusState);
    }

    /**
     *  @notice this function is called by the owner, the purpose is to toggle client type between Light and TSS
     *  @param chain client chain name
     *  @param clientAddress client contract address
     *  @param clientState client status
     *  @param consensusState client consensus status
     */
    function toggleClient(
        string calldata chain,
        address clientAddress,
        bytes calldata clientState,
        bytes calldata consensusState
    ) external onlyAuthorizee(UPGRADE_CLIENT_ROLE) {
        require(IClient(clientAddress).getClientType() != clients[chain].getClientType(), "could not be the same");
        clients[chain] = IClient(clientAddress);
        clients[chain].initializeState(clientState, consensusState);
    }

    /**
     *  @notice registerRelayer register the relayer on the chain
     */
    function registerRelayer(Relayer memory relayer) external onlyAuthorizee(REGISTER_RELAYER_ROLE) {
        require(
            relayer.chains.length > 0 && relayer.chains.length == relayer.chainAddrs.length,
            "invalid chains or addresses"
        );
        for (uint256 i; i < relayers.length; i++) {
            if (relayers[i].addr == relayer.addr) {
                delete relayers[i];
                break;
            }
        }
        relayers.push(relayer);
    }

    /**
     *  @notice revokeRelayer revoke the relayer's authority
     */
    function revokeRelayer(uint256 index) external onlyAuthorizee(REGISTER_RELAYER_ROLE) {
        delete relayers[index];
    }

    /**
     * @notice authenticate the relayer
     * @return return the relayer is registerd or not
     */
    function authRelayer(address relayer) public view returns (bool) {
        for (uint256 i; i < relayers.length; i++) {
            if (relayers[i].addr == relayer) {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice getRelayerChainAddress returns the chain address of the relayer
     * @return return the relayer address on the specified chain
     */
    function getRelayerChainAddress(address relayer, string calldata chain) external view returns (string memory) {
        for (uint256 i; i < relayers.length; i++) {
            if (relayers[i].addr == relayer) {
                for (uint256 j; j < relayers[i].chains.length; j++) {
                    if (relayers[i].chains[j].equals(chain)) {
                        return relayers[i].chainAddrs[j];
                    }
                }
            }
        }
        return "";
    }

    /**
     * @notice getRelayerByChainAddress returns the relayer address
     * @return return the relayer by the specified chain and address
     */
    function getRelayerByChainAddress(string calldata chain, string calldata addr) external view returns (address) {
        for (uint256 i; i < relayers.length; i++) {
            for (uint256 j; j < relayers[i].chains.length; j++) {
                if (relayers[i].chains[j].equals(chain) && relayers[i].chainAddrs[j].equals(addr)) {
                    return relayers[i].addr;
                }
            }
        }
        return address(0);
    }

    /**
     *  @notice obtain the contract address of the client
     *  @param chain client chain name
     */
    function getClientType(string calldata chain) public view override returns (IClient.Type) {
        return clients[chain].getClientType();
    }

    /**
     *  @notice get the latest height of the client update
     *  @param chain client chain name
     */
    function getLatestHeight(string calldata chain) public view override returns (Height.Data memory) {
        return clients[chain].getLatestHeight();
    }
}
