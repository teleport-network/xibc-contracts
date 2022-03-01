// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface ITestRecl {
    function getether() external;
}

contract TestRecl is ITestRecl,ReentrancyGuard {
    receive() external payable {}

    function saveValue() external payable {
        require(msg.value > 0, "err value");
    }

    function getether() nonReentrant external override  {
        (bool success, bytes memory res) = msg.sender.call{value: 100}("");
    }
}
