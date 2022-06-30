# XIBC-Contracts

[XIBC](https://chain-docs.teleport.network/modules/XIBC) implementation in Solidity.

- `chains/01-teleport` is available for [Teleport chain](https://chain-docs.teleport.network). Teleport chain also acts as a relay chain, so its implementation has some minor differences from evm contracts.

- `chains/02-evm` is available for any blockchain that runs smart contract in EVM.

- `token/erc20` is the recommended ERC20 contract for XIBC cross-chain token transfer, including mint and burn functions.

## Compile & Test

Parepare

```bash
git clone https://github.com/celestiaorg/protobuf3-solidity.git
cd protobuf3-solidity
make & mv ./bin/protoc-gen-sol ~/go/bin

git clone https://github.com/datachainlab/solidity-protobuf.git
export SOLPB_DIR={path to solidity-protobuf}

# require python version 3
pip install -r requirements.txt
```

Compile proto file for test

```bash
# install protobufjs
npm install -g protobufjs

# compile proto
pbjs -t static-module -w commonjs -o ./test/proto/compiled.js ./proto/*.proto

# compile project
yarn & yarn compile

# test
yarn test
```

## ERC20-Contract

[ERC20](https://eips.ethereum.org/EIPS/eip-20) contract with mint and burn functions.

**Testnet deploy**

- rinkeby

    ```bash
    yarn hardhat deployToken --name $TOKEN_NAME --symbol $TOKEN_SYMBOL --decimals $DECIMAL --endpoint $ENDPOINT_CONTRACT_ADDRESS --network $NETWORK_NAME
    # example
    yarn hardhat deployToken --name USDT --symbol USDT --decimals 6 --endpoint $ENDPOINT_CONTRACT_ADDRESS --network rinkeby
    ```

    example-address: https://rinkeby.etherscan.io/token/0x0328787d1b6bdc5a215df7ddd2e339c49e827289

- bsc

    ```bash
    yarn hardhat deployToken --name $TOKEN_NAME --symbol $TOKEN_SYMBOL --decimals $DECIMAL --endpoint $ENDPOINT_CONTRACT_ADDRESS --network $NETWORK_NAME
    # example
    yarn hardhat deployToken --name USDT --symbol USDT --decimals 18 --endpoint $ENDPOINT_CONTRACT_ADDRESS --network bsctest
    ```

    example-address:https://testnet.bscscan.com/token/0x44de7218b9f7a205084466d9ad7f438ec30dc192

- teleport

    ```bash
    yarn hardhat deployToken --name $TOKEN_NAME --symbol $TOKEN_SYMBOL --decimals $DECIMAL --endpoint $ENDPOINT_CONTRACT_ADDRESS --network teleport
    # example
    yarn hardhat deployToken --name USDT --symbol USDT --decimals 18 --endpoint $ENDPOINT_CONTRACT_ADDRESS --network teleport
    ```

- faucet repo

    https://github.com/teleport-network/erc20-faucet

## EVM-Contracts

XIBC implementation for Ethereum Compatible Chain.

**Deploy contract**

```bash
# Export env
export NETWORK_NAME={network}
export SUPER_ADMIN={super_admin}

# Deploy libraries
yarn hardhat deployLibraries --network $NETWORK_NAME

# Deploy AccessManager
# The <native-chain-name> requires at least 9 characters in the cross-chain protocol.
yarn hardhat deployAcessManager --network $NETWORK_NAME --wallet $SUPER_ADMIN

# Deploy ClientManager
yarn hardhat deployClientManager --network $NETWORK_NAME

# Deploy Tendermint Client
# When multiple light clients need to be created, multiple instances need to be deployed (Tendermint contracts)
yarn hardhat deployTendermint --network $NETWORK_NAME

# Deploy Packet
yarn hardhat deployPacket --chain $CHAIN_NAME --relaychain teleport --network $NETWORK_NAME

# Deploy Endpoint
yarn hardhat deployEndpoint --network $NETWORK_NAME

# Deploy Execute
yarn hardhat deployExecute --network $NETWORK_NAME

# Set endpoint and execute address in Packet
yarn hardhat initPacket --network $NETWORK_NAME

# Check to xibc-app repo then deploy Proxy Contract
# repo:https://github.com/teleport-network/xibc-apps/tree/main/bridge
# Deploy Proxy
yarn hardhat deployProxy --network $NETWORK_NAME 
```

**Across the chain**

Create lightClient

```bash
yarn hardhat createClientFromFile --client $TENDERMINT_CLIENT --clientstate $CLIENT_STATE_PATH --consensusstate $CONSENSUS_STATE_PATH  --network $NETWORK_NAME
```

Deploy Token

```bash
yarn hardhat deployToken --name $TOKEN_NAME --symbol $TOKEN_SYMBOL --decimals $DECIMAL --endpoint $ENDPOINT_CONTRACT_ADDRESS --network $NETWORK_NAME
```

Cross chain call

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
