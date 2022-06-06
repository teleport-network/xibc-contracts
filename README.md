# XIBC-Contracts

[XIBC](https://chain-docs.teleport.network/modules/XIBC) implementation in Solidity.

* [evm](./evm.md) is available for any blockchain that runs smart contract in EVM.

* [teleport](./teleport.md) is available for [Teleport chain](https://chain-docs.teleport.network). Teleport chain also acts as a relay chain, so its implementation has some minor differences from [evm](./evm).

* [erc20](./erc20.md) is the recommended ERC20 contract for XIBC cross-chain token transfer, including mint and burn functions.

## Compile & Test

```bash
cd {project_path}/{sub_path}
yarn & yarn compile
yarn test
```
