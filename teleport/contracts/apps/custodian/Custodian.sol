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

contract Custodian {
    using Strings for *;
    using Bytes for *;

    address public constant transferContract =
        address(0x0000000000000000000000000000000010000003);

    address public constant rccContract =
        address(0x0000000000000000000000000000000010000004);

    modifier onlyXIBCModuleRCC() {
        require(msg.sender == rccContract, "caller must be XIBC RCC module");
        _;
    }

    function Test() external onlyXIBCModuleRCC {
        // TODO
        IRCC(rccContract).getLatestPacket();
    }
}
