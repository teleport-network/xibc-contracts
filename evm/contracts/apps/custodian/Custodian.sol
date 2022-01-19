// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "../../libraries/utils/Bytes.sol";
import "../../libraries/utils/Strings.sol";
import "../../libraries/app/Transfer.sol";
import "../../libraries/app/RCC.sol";
import "../../interfaces/IMultiCall.sol";
import "../../interfaces/ITransfer.sol";
import "../../interfaces/IRCC.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Custodian is Initializable, OwnableUpgradeable {
    using Strings for *;
    using Bytes for *;

    ITransfer public transfer;
    IRCC public rcc;

    modifier onlyXIBCModuleRCC() {
        require(msg.sender == address(rcc), "caller must be XIBC RCC Contract");
        _;
    }

    function initialize(address transferContract, address rccContract)
        public
        initializer
    {
        transfer = ITransfer(transferContract);
        rcc = IRCC(rccContract);
    }

    function Test() external onlyXIBCModuleRCC {
        // TODO
    }
}
