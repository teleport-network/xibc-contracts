# EVM-Contracts

XIBC implementation for Ethereum Compatible Chain.

**Parepare**

```bash
git clone https://github.com/celestiaorg/protobuf3-solidity.git
cd protobuf3-solidity
make & mv ./bin/protoc-gen-sol ~/go/bin

git clone https://github.com/datachainlab/solidity-protobuf.git
export SOLPB_DIR={path to solidity-protobuf}

# require python version 3
pip install -r requirements.txt
```

**Compile**

Compile proto file for test

```bash
# install protobufjs
npm install -g protobufjs

# compile proto
pbjs -t static-module -w commonjs -o ./test/proto/compiled.js ./proto/*.proto

# compile project
yarn & yarn compile
```

**export env**

```bash
export NETWORK_NAME={network}
export SUPER_ADMIN={super_admin}
```

**Deploy contract**

```bash
# Deploy libraries
yarn hardhat deployLibraries --network $NETWORK_NAME

# Deploy AccessManager
# The <native-chain-name> requires at least 9 characters in the cross-chain protocol.
yarn hardhat deployAcessManager --network $NETWORK_NAME --wallet $SUPER_ADMIN

# Deploy ClientManager
yarn hardhat deployClientManager --network $NETWORK_NAME --chain eth 

# Deploy Tendermint Client
# When multiple light clients need to be created, multiple instances need to be deployed (Tendermint contracts)
yarn hardhat deployTendermint --network $NETWORK_NAME

# Deploy Packet
yarn hardhat deployPacket --network $NETWORK_NAME

# Deploy Endpoint
yarn hardhat deployEndpoint --network $NETWORK_NAME

# Init Endpoint address in Packet
# 

# Deploy Proxy
yarn hardhat deployProxy --network $NETWORK_NAME 
```

**Across the chain**

Create lightClient

```bash
yarn hardhat createClientFromFile --chain teleport --client $TENDERMINT_CLIENT --clientstate $CLIENT_STATE_PATH --consensusstate $CONSENSUS_STATE_PATH --network $NETWORK_NAME
```

Deploy Token

```bash
yarn hardhat deployToken --name $TOKEN_NAME --symbol $TOKEN_SYMBOL --network $NETWORK_NAME
```

Call TransferToken

```bash
yarn hardhat transferToken \
    --transfer $TRANSFER_CONTRACT_ADDRESS \
    --address $TOKEN_ADDRESS \
    --receiver $RECEIVER_ADDRESS \
    --amount $AMOUNT \
    --dstchain $DST_CHAIN \
    --relaychain $RELAY_CHAIN_NAME \
    --relayfeeaddress $FEE_TOKEN \
    --relayfeeamout $FEE_AMOUNT \
    --network $NETWORK_NAME
```
