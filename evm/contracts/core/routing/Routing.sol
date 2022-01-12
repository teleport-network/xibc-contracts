// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../../libraries/utils/Strings.sol";
import "../../interfaces/IRouting.sol";
import "../../interfaces/IModule.sol";
import "../../interfaces/IAccessManager.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

contract Routing is Initializable, OwnableUpgradeable, IRouting {
    using Strings for *;

    mapping(string => IModule) public modules;
    // access control contract
    IAccessManager public accessManager;

    bytes32 public constant ADD_ROUTING_ROLE = keccak256("ADD_ROUTING_ROLE");

    // only authorized accounts can perform related transactions
    modifier onlyAuthorizee(bytes32 role) {
        require(accessManager.hasRole(role, _msgSender()), "not authorized");
        _;
    }

    function initialize(address accessManagerContract) public initializer {
        accessManager = IAccessManager(accessManagerContract);
    }

    /**
     *  @notice return the module contract instance with the specified name
     *  @param port port of the app module
     */
    function getModule(string calldata port)
        external
        view
        override
        returns (IModule)
    {
        return modules[port];
    }

    /**
     * @notice add a module:
     * @param port port of the app module
     * @param moduleContract module contract address
     */
    function addRouting(string calldata port, address moduleContract)
        external
        onlyAuthorizee(ADD_ROUTING_ROLE)
    {
        modules[port] = IModule(moduleContract);
    }
}
