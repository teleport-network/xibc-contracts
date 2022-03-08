// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

library RCCDataTypes {
    struct RCCData {
        string contractAddress;
        bytes data;
        string destChain;
        string relayChain;
    }

    struct RCCDataMulti {
        address sender;
        string contractAddress;
        bytes data;
        string destChain;
    }

    struct PacketData {
        string srcChain;
        string destChain;
        uint64 sequence;
        string sender;
        string contractAddress;
        bytes data;
    }
}
