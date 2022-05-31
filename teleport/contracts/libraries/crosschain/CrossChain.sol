// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

library TransferDataTypes {
    struct InToken {
        string oriToken; // token ID, address if ERC20
        uint256 amount;
        uint8 scale; // real_amount = packet_amount * (10 ** scale)
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
        string dstChain;
        // transfer token data
        address tokenAddress; // zero address if base token
        uint256 amount;
        string receiver;
        // contract call data
        string contractAddress;
        bytes callData;
        // callback data
        address callbackAddress;
        // fee option
        uint64 feeOption;
    }
}
