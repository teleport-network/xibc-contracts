// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

library TransferDataTypes {
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

    struct InToken {
        string oriToken; // token ID, address if ERC20
        uint256 amount;
        bool bound;
    }

    struct PacketData {
        string srcChain;
        string destChain;
        string sender;
        string receiver;
        bytes amount;
        string token; // must be lowercase
        string oriToken; // if oriToken not null, means back
    }
}
