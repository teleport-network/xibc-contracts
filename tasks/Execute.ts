import "@nomiclabs/hardhat-web3"
import { task } from "hardhat/config"

const PACKET_ADDRESS = process.env.PACKET_ADDRESS
const NOT_PROXY = process.env.NOT_PROXY

task("deployExecute", "Deploy Execute")
    .setAction(async (taskArgs, hre) => {
        const executeFactory = await hre.ethers.getContractFactory('contracts/chains/02-evm/core/endpoint/Execute.sol:Execute')
        if (NOT_PROXY) {
            const execute = await executeFactory.deploy()
            await execute.deployed()

            console.log("Execute deployed !")
            console.log("export EXECUTE_ADDRESS=%s", execute.address.toLocaleLowerCase())
        } else {
            const execute = await hre.upgrades.deployProxy(
                executeFactory,
                [
                    String(PACKET_ADDRESS),
                ],
            )
            await execute.deployed()
            console.log("Execute deployed to:", execute.address.toLocaleLowerCase())
            console.log("export EXECUTE_ADDRESS=%s", execute.address.toLocaleLowerCase())
        }
    })
