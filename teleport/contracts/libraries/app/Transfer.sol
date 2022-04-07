// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

library TransferDataTypes {
    struct TransferData {
        address tokenAddress; // zero address if base token
        string receiver;
        uint256 amount;
        string destChain;
        string relayChain;
    }

    struct TransferDataMulti {
        address tokenAddress; // zero address if base token
        address sender;
        string receiver;
        uint256 amount;
        string destChain;
    }

    struct InToken {
        string oriToken; // token ID, address if ERC20
        uint256 amount;
        uint8 scale; // real_amount = packet_amount * (10 ** scale)
        bool bound;
    }

    struct PacketData {
        string srcChain;
        string destChain;
        uint64 sequence;
        string sender;
        string receiver;
        bytes amount;
        string token; // must be lowercase
        string oriToken; // if oriToken not null, means back
    }
}
