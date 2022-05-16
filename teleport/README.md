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
yarn hardhat transferBase \
    --transfer $TRANSFER_CONTRACT_ADDRESS \
    --address $TOKEN_ADDRESS \
    --receiver $RECEIVER_ADDRESS \
    --amount $AMOUNT \
    --destchain $DEST_CHAIN \
    --relaychain $RELAY_CHAIN_NAME \
    --relayfeeaddress $FEE_TOKEN \
    --relayfeeamout $FEE_AMOUNT \
    --network $NETWORK_NAME
```
