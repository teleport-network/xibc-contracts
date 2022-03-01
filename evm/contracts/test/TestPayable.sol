// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "./testRecl.sol";
import "hardhat/console.sol";

contract TestPayable {
    receive() external payable {
        console.log("in TestPayable receive");
        num++;
        if (num != 10) {
            console.log("num : ", num);
            recl.getether();
        }
    }

    uint64 public num = 0;

    ITestRecl public recl;

    function send(address cat) external payable returns  (bool) {
        return payable(cat).send(msg.value);
    }

    function call(address cat) external payable returns (bool) {
        (bool success, bytes memory res) = cat.call{value: msg.value}("");
        return success;
    }

    function transfer(address cat) external payable{
        payable(cat).transfer(msg.value);
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function proxySend(address _recl) external {
        recl = ITestRecl(_recl);
        recl.getether();
    }
}
