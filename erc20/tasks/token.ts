import "@nomiclabs/hardhat-web3"
import { task } from "hardhat/config"
import fs = require('fs');

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
        fs.appendFileSync('env.txt', 'export ' + taskArgs.name + '=' + token.address.toLocaleLowerCase() + '\n')
    });

task("mintToken", "Deploy Token")
    .addParam("address", "token address")
    .addParam("to", "reciver")
    .addParam("amount", "token mint amount")
    .setAction(async (taskArgs, hre) => {
        const tokenFactory = await hre.ethers.getContractFactory('ERC20MinterBurnerDecimals')
        const token = await tokenFactory.attach(taskArgs.address)

        console.log(await token.mint(taskArgs.to, taskArgs.amount))
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
        fs.appendFileSync('env.txt', 'export ' + taskArgs.name + '=' + token.address.toLocaleLowerCase() + '\n')
    });

task("hasRole", "Deploy Token")
    .addParam("address", "ERC20 contract address")
    .addParam("transfer", "transfer address")
    .setAction(async (taskArgs, hre) => {
        const tokenFactory = await hre.ethers.getContractFactory('ERC20MinterBurnerDecimals')
        const token = await tokenFactory.attach(taskArgs.address)

        console.log("MINTER_ROLE",await token.hasRole(keccak256("MINTER_ROLE"), taskArgs.transfer))
        console.log("BURNER_ROLE",await token.hasRole(keccak256("BURNER_ROLE"), taskArgs.transfer))
    });

task("grantRole", "Deploy Token")
    .addParam("address", "ERC20 contract address")
    .addParam("account", "account address")
    .setAction(async (taskArgs, hre) => {
        const tokenFactory = await hre.ethers.getContractFactory('ERC20MinterBurnerDecimals')
        const token = await tokenFactory.attach(taskArgs.address)

        console.log(await token.grantRole(keccak256("MINTER_ROLE"), taskArgs.account))
        console.log(await token.grantRole(keccak256("BURNER_ROLE"), taskArgs.account))
    });

task("burnToken", "Burn Token")
    .addParam("address", "token address")
    .addParam("from", "reciver")
    .addParam("amount", "token mint amount")
    .setAction(async (taskArgs, hre) => {
        const tokenFactory = await hre.ethers.getContractFactory('ERC20MinterBurnerDecimals')
        const token = await tokenFactory.attach(taskArgs.address)

        console.log(await token.burnCoins(taskArgs.from, taskArgs.amount))
    });