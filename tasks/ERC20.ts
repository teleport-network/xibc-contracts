import "@nomiclabs/hardhat-web3"
import { task } from "hardhat/config"
import { keccak256 } from "ethers/lib/utils"

task("deployToken", "Deploy Token")
    .addParam("name", "token name")
    .addParam("symbol", "token symbol")
    .addParam("decimals", "erc20 decimals")
    .addParam("endpoint", "endpoint address")
    .setAction(async (taskArgs, hre) => {
        const tokenFactory = await hre.ethers.getContractFactory('ERC20MinterBurnerDecimals')
        const token = await tokenFactory.deploy(taskArgs.name, taskArgs.symbol, taskArgs.decimals, taskArgs.endpoint)
        await token.deployed();

        console.log("Token %s deployed to:%s", taskArgs.name, token.address.toLocaleLowerCase());
        console.log("export ERC20_TOKEN=%s", token.address.toLocaleLowerCase());
    });

task("roleCheck", "Mint Token")
    .addParam("token", "erc20 token address")
    .addParam("address", "role address")
    .setAction(async (taskArgs, hre) => {
        const tokenFactory = await hre.ethers.getContractFactory('ERC20MinterBurnerDecimals')
        const token = await tokenFactory.attach(taskArgs.token)

        console.log("mint role : ", await token.hasRole(keccak256(Buffer.from("MINTER_ROLE", "utf-8")), taskArgs.address))
        console.log("burn role : ", await token.hasRole(keccak256(Buffer.from("BURNER_ROLE", "utf-8")), taskArgs.address))
    });

task("roleGrant", "Mint Token")
    .addParam("token", "erc20 token address")
    .addParam("address", "role address")
    .setAction(async (taskArgs, hre) => {
        const tokenFactory = await hre.ethers.getContractFactory('ERC20MinterBurnerDecimals')
        const token = await tokenFactory.attach(taskArgs.token)

        if (!await token.hasRole(keccak256(Buffer.from("MINTER_ROLE", "utf-8")), taskArgs.address)) {
            await token.grantRole(keccak256(Buffer.from("MINTER_ROLE", "utf-8")), taskArgs.address)
            console.log("grant mint role success!")
        } else if (!await token.hasRole(keccak256(Buffer.from("BURNER_ROLE", "utf-8")), taskArgs.address)) {
            await token.grantRole(keccak256(Buffer.from("BURNER_ROLE", "utf-8")), taskArgs.address)
            console.log("grant burn role success!")
        }else {
            console.log("already has mint role and burn role!")
        }
    });

task("mintToken", "Mint Token")
    .addParam("token", "token address")
    .addParam("to", "reciver")
    .addParam("amount", "token mint amount")
    .setAction(async (taskArgs, hre) => {
        const tokenFactory = await hre.ethers.getContractFactory('ERC20MinterBurnerDecimals')
        const token = await tokenFactory.attach(taskArgs.token)

        await token.mint(taskArgs.to, taskArgs.amount)
    });

task("queryErc20balances", "Query ERC20 balances")
    .addParam("token", "token address")
    .addParam("user", "user address ")
    .setAction(async (taskArgs, hre) => {
        const tokenFactory = await hre.ethers.getContractFactory('ERC20MinterBurnerDecimals')
        const token = await tokenFactory.attach(taskArgs.token)

        let balances = (await token.balanceOf(taskArgs.user)).toString()
        console.log(balances)
    });

task("approve", "approve ERC20 token to others")
    .addParam("token", "erc20 address")
    .addParam("to", "to address ")
    .addParam("amount", "approve amount")
    .setAction(async (taskArgs, hre) => {
        const tokenFactory = await hre.ethers.getContractFactory('ERC20MinterBurnerDecimals')
        const token = await tokenFactory.attach(taskArgs.token)

        let res = await token.approve(taskArgs.to, taskArgs.amount)
        console.log(res)
    });

task("queryAllowance", "Query ERC20 allowance")
    .addParam("token", "erc20 address")
    .addParam("to", "to address ")
    .addParam("account", "account address")
    .setAction(async (taskArgs, hre) => {
        const tokenFactory = await hre.ethers.getContractFactory('ERC20MinterBurnerDecimals')
        const token = await tokenFactory.attach(taskArgs.token)

        let allowances = (await token.allowance(taskArgs.account, taskArgs.to))
        console.log(allowances)
    });

module.exports = {}
