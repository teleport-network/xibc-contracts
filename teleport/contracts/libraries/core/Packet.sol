// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

library PacketTypes {
    struct Fee {
        address tokenAddress; // zero address if base token
        uint256 amount;
    }
}