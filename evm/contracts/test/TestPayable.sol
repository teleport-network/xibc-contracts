// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

contract TestPayable {
    receive() external payable {}

    function send(address cat, uint256 amount) external returns (bool) {
        return payable(cat).send(amount);
    }

    function call(address cat, uint256 amount) external returns (bool) {
        (bool success, bytes memory res) = cat.call{value: amount}("");
        return success;
    }

    function transfer(address cat, uint256 amount) external {
        payable(cat).transfer(amount);
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
