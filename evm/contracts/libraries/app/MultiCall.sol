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

    struct ERC20TransferData {
        address tokenAddress;
        string receiver;
        uint256 amount;
    }

    struct BaseTransferData {
        string receiver;
        uint256 amount;
    }

    struct RCCData {
        string contractAddress;
        bytes data;
    }
}
