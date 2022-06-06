# Teleport-Contracts

XIBC implementation for Teleport chain.

**Compile**

```bash
# compile project
yarn & yarn compile
```

**Across the chain**

Call Transfer

```bash
yarn hardhat crossChain \
    --dstchain $DST_CHAIN \
    --token $TOKEN_ADDRESS \
    --receiver $RECEIVER \
    --amount $AMOUNT \
    --contract $CONTRACT_ADDRESS \
    --calldata $CALLDATA \
    --callback $CALLBACK_ADDRESS \
    --feetoken $FEE_TOKEN_ADDRESS \
    --feeamout $FEE_AMOUNT \
    --network $NETWORK_NAME
```
