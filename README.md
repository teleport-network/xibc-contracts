# XIBC-Contracts

[XIBC](https://chain-docs.teleport.network/modules/XIBC) implementation in Solidity.

* [evm](./evm) is available for any blockchain that runs smart contract in EVM.

* [teleport](./teleport) is available for [Teleport chain](https://chain-docs.teleport.network). Teleport chain also acts as a relay chain, so its implementation has some minor differences from [evm](./evm).

* [erc20](./erc20) is the recommended ERC20 contract for XIBC cross-chain token transfer, including mint and burn functions.

## Compile & Test

```
cd {project_path}/{sub_path}
yarn & yarn compile
yarn test
```