# ERC20-Contract

[ERC20](https://eips.ethereum.org/EIPS/eip-20) contract with mint and burn functions.

## Testnet deploy

Should set networks url in `hardhat.config.ts` first.

### rinkeby

```bash
yarn hardhat deployTestToken --name $TOKEN_NAME --symbol $TOKEN_SYMBOL --decimals $DECIMAL --transfer $TRANSFER_CONTRACT_ADDRESS --network $NETWORK_NAME
```

example

```bash
yarn hardhat deployTestToken --name USDT --symbol USDT --decimals 6 --transfer $TRANSFER_CONTRACT_ADDRESS --network rinkeby
```

example-address: https://rinkeby.etherscan.io/token/0xce6f517236f122fc5a718d6dc15f0c52e2c2a17b

### bsc

```bash
yarn hardhat deployTestToken --name $TOKEN_NAME --symbol $TOKEN_SYMBOL --decimals $DECIMAL --transfer $TRANSFER_CONTRACT_ADDRESS --network $NETWORK_NAME
```

example

```bash
yarn hardhat deployTestToken --name USDT --symbol USDT --decimals 18 --transfer $TRANSFER_CONTRACT_ADDRESS --network bsctest
```

example-address:https://testnet.bscscan.com/token/0x53205b9371ece357c4f792a90652b2f74503c60e

### teleport

```bash
yarn hardhat deployTestToken --name $TOKEN_NAME --symbol $TOKEN_SYMBOL --decimals $DECIMAL --transfer $TRANSFER_CONTRACT_ADDRESS --network teleport
```

example

```bash
yarn hardhat deployTestToken --name USDT --symbol USDT --decimals 18 --transfer $TRANSFER_CONTRACT_ADDRESS --network teleport
```

### faucet repo

https://github.com/teleport-network/erc20-faucet
