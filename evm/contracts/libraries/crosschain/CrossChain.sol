// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

library TokenBindingTypes {
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
}

library CrossChainDataTypes {
    struct CrossChainData {
        // path data
        string destChain;
        string relayChain;
        // transfer token data
        address tokenAddress; // zero address if base token
        string receiver;
        uint256 amount;
        // contract call data
        string contractAddress;
        bytes callData;
        // callback data
        string callbackAddress;
        // fee option
        uint64 feeOption;
    }
}
