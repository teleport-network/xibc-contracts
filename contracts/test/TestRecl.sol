// // SPDX-License-Identifier: Apache-2.0

// pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// interface ITestRecl {
//     function getether() external;
// }

// contract TestRecl is ITestRecl, ReentrancyGuard {
//     receive() external payable {}

//     function saveValue() external payable {
//         require(msg.value > 0, "err value");
//     }

//     function getether() external override nonReentrant {
//         msg.sender.call{value: 100}("");
//     }
// }
