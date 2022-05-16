# ERC20-Contract

[ERC20](https://eips.ethereum.org/EIPS/eip-20) contract with mint and burn functions.

### Testnet deploy

##### rinkeby
```shell
yarn hardhat deployTestToken --name $TokenName --symbol $TokenSymbol --decimals 6 --transfer $transferaddress --network $NETWORK_NAME
```

example
```shell
yarn hardhat deployTestToken --name USDT --symbol USDT --decimals 6 --transfer 0xcd0b4e309fb855d644ba64e5fb3dc3dd08f13917 --network rinkeby
```

example-address: https://rinkeby.etherscan.io/token/0xce6f517236f122fc5a718d6dc15f0c52e2c2a17b

#### bsc
```shell
yarn hardhat deployTestToken --name $TokenName --symbol $TokenSymbol --decimals 18 --transfer $transferaddress --network $NETWORK_NAME
```

example
```shell
yarn hardhat deployTestToken --name USDT --symbol USDT --decimals 18 --transfer 0xcd0b4e309fb855d644ba64e5fb3dc3dd08f13917 --network bsctest
```
example-address:https://testnet.bscscan.com/token/0x53205b9371ece357c4f792a90652b2f74503c60e

### teleport
```shell
yarn hardhat deployTestToken --name USDT --symbol USDT --decimals 18 --transfer 0xcd0b4e309fb855d644ba64e5fb3dc3dd08f13917 --network teleport
```

example
```shell
yarn hardhat deployTestToken --name USDT --symbol USDT --decimals 18 --transfer 0xcd0b4e309fb855d644ba64e5fb3dc3dd08f13917 --network teleport
```

### faucet repo:

https://github.com/teleport-network/erc20-faucet
