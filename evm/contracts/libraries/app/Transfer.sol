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

    struct TimeBasedSupplyLimit {
        bool enable;
        uint256 timePeriod; // seconds
        uint256 timeBasedLimit;
        uint256 maxAmount;
        uint256 minAmount;
        uint256 previousTime; // timestamp (seconds)
        uint256 currentSupply;
    }

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

    struct TransferPacketData {
        string srcChain;
        string destChain;
        uint64 sequence;
        string sender;
        string receiver;
        bytes amount;
        string token;
        string oriToken;
    }
}
