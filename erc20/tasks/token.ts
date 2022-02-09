import "@nomiclabs/hardhat-web3"
import { task, types } from "hardhat/config"
const keccak256 = require('keccak256')

task("deployToken", "Deploy Token")
    .addParam("name", "token name")
    .addParam("symbol", "token symbol")
    .addParam("decimals", "decimals")
    .addParam("transfer", "transfer address")
    .setAction(async (taskArgs, hre) => {
        const tokenFactory = await hre.ethers.getContractFactory('ERC20MinterBurnerDecimals')
        const token = await tokenFactory.deploy(taskArgs.name, taskArgs.symbol, taskArgs.decimals, taskArgs.transfer)
        await token.deployed();

        console.log("Token %s deployed to:%s", taskArgs.name, token.address.toLocaleLowerCase());
        console.log("export ERC20_TOKEN=%s", token.address.toLocaleLowerCase());
    });

task("deployTestToken", "Deploy Testnet ERC20 Token")
    .addParam("name", "token name")
    .addParam("symbol", "token symbol")
    .addParam("decimals", "decimals")
    .addParam("transfer", "transfer address")
    .setAction(async (taskArgs, hre) => {
        const tokenFactory = await hre.ethers.getContractFactory('TESTERC20MinterBurnerDecimals')
        const token = await tokenFactory.deploy(taskArgs.name, taskArgs.symbol, taskArgs.decimals, taskArgs.transfer)
        await token.deployed();

        console.log("Token %s deployed to:%s", taskArgs.name, token.address.toLocaleLowerCase());
        console.log("export ERC20_TOKEN=%s", token.address.toLocaleLowerCase());
    });

task("hasMinterRole", "Deploy Token")
    .addParam("address", "ERC20 contract address")
    .addParam("transfer", "transfer address")
    .setAction(async (taskArgs, hre) => {
        const tokenFactory = await hre.ethers.getContractFactory('ERC20MinterBurnerDecimals')
        const token = await tokenFactory.attach(taskArgs.address)

        console.log(await token.hasRole(keccak256("MINTER_ROLE"), taskArgs.transfer))
    });
