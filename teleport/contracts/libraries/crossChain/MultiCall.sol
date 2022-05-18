// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

library MultiCallDataTypes {
    struct MultiCallData {
        string destChain;
        string relayChain;
        uint8[] functions;
        bytes[] data;
    }

    struct TransferData {
        address tokenAddress; // zero address if base token
        string receiver;
        uint256 amount;
    }

    struct RCCData {
        string contractAddress;
        bytes data;
    }
}
