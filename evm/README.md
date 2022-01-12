# XIBC Contracts

**Parepare**

```bash
git clone https://github.com/celestiaorg/protobuf3-solidity.git
cd protobuf3-solidity
make & mov ./bin/protoc-gen-sol ~/go/bin

git clone https://github.com/datachainlab/solidity-protobuf.git
export SOLPB_DIR={path to solidity-protobuf}

# require python version 3
pip install -r requirements.txt
```

**Compile**

```bash
# install protobufjs
npm install -g protobufjs

# ccompile proto
pbjs -t static-module -w commonjs -o ./test/proto/compiled.js ./proto/*.proto

# compile project
yarn & yarn compile
```

**export env**

```bash
export NETWORK_NAME=ropsten
export SUPER_ADMIN=0xE3b552144F0adB3353CaF94B1e252714FeF5fc12
```

**Deploy contract**

```bash
# Deploy libraries
yarn hardhat deployLibraries --network $NETWORK_NAME
# Deploy AccessManager
# The <native-chain-name> requires at least 9 characters in the cross-chain protocol.
yarn hardhat deployAcessManager --network $NETWORK_NAME --wallet $SUPER_ADMIN

# Deploy ClientManager
yarn hardhat deployClientManager --network $NETWORK_NAME --chain eth --accm $ACCESS_MANAGER_ADDRES

# Deploy Tendermint Client
# When multiple light clients need to be created, multiple instances need to be deployed (Tendermint contracts)
yarn hardhat deployTendermint --network $NETWORK_NAME

# Deploy Routing
yarn hardhat deployRouting --network $NETWORK_NAME --accm $ACCESS_MANAGER_ADDRES

# Deploy Packet
yarn hardhat deployPacket --network $NETWORK_NAME

# Deploy Transfer
yarn hardhat deployTransfer --network $NETWORK_NAME
```

**Across the chain**
Create lightClient

```bash
yarn hardhat createClientFromFile  --chain teleport --client $TENDERMINT_CLIENT  --clientstate  $CLIENT_STATE_PATH --consensusstate $CONSENSUS_STATE_PATH  --network $NETWORK_NAME
```

Deploy Token

```bash
yarn hardhat deployToken  --network  $NETWORK_NAME
```

Register relayer

```bash
yarn hardhat registerRelayer  --chain teleport  --relayer  $SUPER_ADMIN   --network $NETWORK_NAME
```

Call TransferBase

```bash
yarn hardhat transferBase  --transfer $TRANSFER_ADDRES --address 0x0000000000000000000000000000000010000003  --receiver  0xFd805Fc7f5B60849dbA893168708AAFDD181fCf3 --destchain  eth  --amount 20   --network teleport
```

Call TransferERC20

```bash
yarn hardhat transferERC20 --address 0x582e0992cb1EaE9B1AbcBF889EE640626453259F  --transfer $TRANSFER_ADDRES   --receiver 0xFd805Fc7f5B60849dbA893168708AAFDD181fCf3   --amount 10 --destChain destChain  --network ropsten
```
