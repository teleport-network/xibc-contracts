// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

library TransferDataTypes {
    struct InToken {
        string oriChain;
        string oriToken;
        uint256 amount;
        bool bound;
    }

    struct ERC20TransferData {
        address tokenAddress;
        string receiver;
        uint256 amount;
        string destChain;
        string relayChain;
    }

    struct BaseTransferData {
        string receiver;
        string destChain;
        string relayChain;
    }

    struct ERC20TransferDataMulti {
        address tokenAddress;
        address sender;
        string receiver;
        uint256 amount;
        string destChain;
    }

    struct BaseTransferDataMulti {
        address sender;
        string receiver;
        string destChain;
    }
    
    struct TokenTransfer {
        string srcChain;
        string destChain;
        string sender;
        string receiver;
        bytes amount;
        string token;
        string oriToken;
    }
}
