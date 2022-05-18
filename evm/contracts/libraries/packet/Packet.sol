// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

library PacketTypes {
    struct Packet {
        bytes data;
    }

    struct PacketData {
        // packet base data
        string srcChain;
        string destChain;
        string relayChain;
        uint64 sequence;
        string sender;
        // transfer data. keep empty if not used.
        bytes transferData;
        // call data. keep empty if not used
        bytes callData;
        // callback data
        string callbackAddress;
        // fee option
        uint64 feeOption;
    }

    struct TransferData {
        string receiver;
        bytes amount;
        string token;
        string oriToken;
    }

    struct CallData {
        string contractAddress;
        bytes callData;
    }

    struct Fee {
        address tokenAddress; // zero address if base token
        uint256 amount;
    }

    struct Acknowledgement {
        uint64 code;
        bytes result;
        string message;
        string relayer;
        uint64 feeOption;
    }
}
