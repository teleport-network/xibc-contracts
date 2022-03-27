// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

library PacketTypes {
    struct Packet {
        uint64 sequence;
        string sourceChain;
        string destChain;
        string relayChain;
        string[] ports;
        bytes[] dataList;
    }

    struct Fee {
        address tokenAddress; // zero address if base token
        uint256 amount;
    }

    struct Result {
        bytes result;
        string message;
    }

    struct Acknowledgement {
        bytes[] results;
        string message;
        string relayer;
    }
}
