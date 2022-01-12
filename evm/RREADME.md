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

**Deploy contract**

```bash
# Deploy libraries
yarn hardhat deployLibraries --network teleport

# Deploy AccessManager
# The <native-chain-name> requires at least 9 characters in the cross-chain protocol.
yarn hardhat deployAcessManager --network teleport --wallet <walletAddress>

# Deploy ClientManager
yarn hardhat deployClientManager --network teleport --chain <NativeChainName>

# Deploy Tendermint Client
# When multiple light clients need to be created, multiple instances need to be deployed (Tendermint contracts)
yarn hardhat deployTendermint --network teleport

# Deploy Tss Client
yarn hardhat deployTssClient --network teleport

# Deploy Routing
yarn hardhat deployRouting --network teleport

# Deploy Packet
yarn hardhat deployPacket --network teleport

# Deploy Transfer
yarn hardhat deployTransfer --network teleport
```

**Create CLient**

```bash
# Create tss client
yarn hardhat createTssCLient --network teleport --chain <chain-name> --client <tss client address> --pubkey <tss-pubkey>

# Get tss client
yarn hardhat getTssCLient --network teleport --chain <chain-name>
```
