// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract AccessManager is AccessControlUpgradeable {
    // clientManager
    bytes32 public constant CREATE_CLIENT_ROLE = keccak256("CREATE_CLIENT_ROLE");
    bytes32 public constant UPGRADE_CLIENT_ROLE = keccak256("UPGRADE_CLIENT_ROLE");

    // packet
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");
    bytes32 public constant FEE_MANAGER = keccak256("FEE_MANAGER");

    // endpoint
    bytes32 public constant BIND_TOKEN_ROLE = keccak256("BIND_TOKEN_ROLE");

    // multi-signature contract address
    address public multiSignWallet;

    function initialize(address _multiSignWallet) public initializer {
        multiSignWallet = _multiSignWallet;
        _setupRole(DEFAULT_ADMIN_ROLE, _multiSignWallet);

        // clientManager
        _setupRole(CREATE_CLIENT_ROLE, _multiSignWallet);
        _setupRole(UPGRADE_CLIENT_ROLE, _multiSignWallet);

        // packet
        _setupRole(PAUSER_ROLE, _multiSignWallet);

        // endpoint
        _setupRole(BIND_TOKEN_ROLE, _multiSignWallet);
    }

    /**
     *  @notice authorize a designated role to an address through a multi-signature contract address
     *  @param role       role
     *  @param account    authorized  address
     */
    function grantRole(bytes32 role, address account) public override {
        super.grantRole(role, account);
    }

    /**
     *  @notice cancel the authorization to assign a role to a certain address through the multi-signature contract address
     *  @param role       role
     *  @param account    deauthorized  address
     */
    function revokeRole(bytes32 role, address account) public override {
        super.revokeRole(role, account);
    }

    /**
     *  @notice volume authorization, roles and address need to be one-to-one correspondence
     *  @param roles      collection of roles
     *  @param accounts   collection of accounts
     */
    function batchGrantRole(bytes32[] calldata roles, address[] calldata accounts) external {
        require(roles.length == accounts.length, "batchGrant: roles and accounts length mismatch");

        for (uint256 i = 0; i < roles.length; ++i) {
            super.grantRole(roles[i], accounts[i]);
        }
    }

    /**
     *  @notice batch deauthorization, roles and address need to be one-to-one correspondence
     *  @param roles      collection of roles
     *  @param accounts   collection of accounts
     */
    function batchRevokeRole(bytes32[] calldata roles, address[] calldata accounts) external {
        require(roles.length == accounts.length, "batchRevoke: roles and accounts length mismatch");

        for (uint256 i = 0; i < roles.length; ++i) {
            super.revokeRole(roles[i], accounts[i]);
        }
    }
}
