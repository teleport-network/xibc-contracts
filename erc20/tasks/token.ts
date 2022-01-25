import "@nomiclabs/hardhat-web3"
import { task, types } from "hardhat/config"

task("deployToken", "Deploy Token")
    .addParam("name", "token name")
    .addParam("symbol", "token symbol")
    .addParam("decimals","decimals")
    .setAction(async (taskArgs, hre) => {
        const tokenFactory = await hre.ethers.getContractFactory('ERC20MinterBurnerDecimals')
        const token = await tokenFactory.deploy(taskArgs.name, taskArgs.symbol,taskArgs.decimals)
        await token.deployed();

        console.log("Token %s deployed to:%s", taskArgs.name, token.address.toLocaleLowerCase());
        console.log("export ERC20_TOKEN=%s", token.address.toLocaleLowerCase());

    });