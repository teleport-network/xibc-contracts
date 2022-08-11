import "@nomiclabs/hardhat-web3"
import { task } from "hardhat/config"

const PACKET_AC_ADDRESS = process.env.PACKET_AC_ADDRESS
const PACKET_RC_ADDRESS = process.env.PACKET_RC_ADDRESS
const NOT_PROXY = process.env.NOT_PROXY

task("deployExecute", "Deploy Execute")
    .setAction(async (taskArgs, hre) => {
        const executeFactory = await hre.ethers.getContractFactory('Execute')
        let packet = String(PACKET_AC_ADDRESS)
        if (PACKET_RC_ADDRESS){
            console.log("deploy RC")
            packet = String(PACKET_RC_ADDRESS)
        }else{
            console.log("deploy AC")
        }

        if (NOT_PROXY) {
            const execute = await executeFactory.deploy()
            await execute.deployed()

            console.log("Execute deployed !")
            console.log("export EXECUTE_ADDRESS=%s", execute.address.toLocaleLowerCase())
        } else {
            const execute = await hre.upgrades.deployProxy(
                executeFactory,
                [
                    packet,
                ],
            )
            await execute.deployed()
            console.log("Execute deployed to:", execute.address.toLocaleLowerCase())
            console.log("export EXECUTE_ADDRESS=%s", execute.address.toLocaleLowerCase())
        } 
    })
