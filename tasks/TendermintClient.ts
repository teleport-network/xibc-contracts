import "@nomiclabs/hardhat-web3"
import { task } from "hardhat/config"
import fs = require('fs');

const CLIENT_STATE_CODEC_ADDRESS = process.env.CLIENT_STATE_CODEC_ADDRESS
const CONSENSUS_STATE_CODEC_ADDRESS = process.env.CONSENSUS_STATE_CODEC_ADDRESS
const VERIFIER_ADDRESS = process.env.VERIFIER_ADDRESS
const CLIENT_MANAGER_ADDRESS = process.env.CLIENT_MANAGER_ADDRESS
const LIGHT_CLIENT_VERIFY_ADDRESS = process.env.LIGHT_CLIENT_VERIFY_ADDRESS
const LIGHT_CLIENT_GEN_VALHASH_ADDRESS = process.env.LIGHT_CLIENT_GEN_VALHASH_ADDRESS

const TENDERMINT_CLIENT = process.env.TENDERMINT_CLIENT

task("deployTendermint", "Deploy Tendermint Client")
    .setAction(async (taskArgs, hre) => {
        const HeaderCodec = await hre.ethers.getContractFactory('HeaderCodec')
        const headerCodec = await HeaderCodec.deploy()
        await headerCodec.deployed()
        const tendermintFactory = await hre.ethers.getContractFactory(
            'Tendermint',
            {
                libraries: {
                    ClientStateCodec: String(CLIENT_STATE_CODEC_ADDRESS),
                    ConsensusStateCodec: String(CONSENSUS_STATE_CODEC_ADDRESS),
                    Verifier: String(VERIFIER_ADDRESS),
                    HeaderCodec: String(headerCodec.address),
                    LightClientVerify: String(LIGHT_CLIENT_VERIFY_ADDRESS),
                    LightClientGenValHash: String(LIGHT_CLIENT_GEN_VALHASH_ADDRESS),
                }
            },
        )

        const tendermint = await hre.upgrades.deployProxy(
            tendermintFactory,
            [String(CLIENT_MANAGER_ADDRESS)],
            { "unsafeAllowLinkedLibraries": true }
        )
        await tendermint.deployed()
        console.log("Tendermint deployed to:", tendermint.address.toLocaleLowerCase())
        console.log("export TENDERMINT_CLIENT=%s", tendermint.address.toLocaleLowerCase())
        fs.appendFileSync('env.txt', 'export TENDERMINT_CLIENT=' + tendermint.address.toLocaleLowerCase() + '\n')
    })



task("upgradeTendermint", "upgrade Tendermint Client")
    .setAction(async (taskArgs, hre) => {
        const HeaderCodec = await hre.ethers.getContractFactory('HeaderCodec')
        const headerCodec = await HeaderCodec.deploy()
        await headerCodec.deployed()
        const tendermintFactory = await hre.ethers.getContractFactory(
            'Tendermint',
            {
                libraries: {
                    ClientStateCodec: String(CLIENT_STATE_CODEC_ADDRESS),
                    ConsensusStateCodec: String(CONSENSUS_STATE_CODEC_ADDRESS),
                    Verifier: String(VERIFIER_ADDRESS),
                    HeaderCodec: String(headerCodec.address),
                    LightClientVerify: String(LIGHT_CLIENT_VERIFY_ADDRESS),
                    LightClientGenValHash: String(LIGHT_CLIENT_GEN_VALHASH_ADDRESS),
                }
            },
        )
        const tendermint = await hre.upgrades.upgradeProxy(
            String(TENDERMINT_CLIENT),
            tendermintFactory,
        )
        console.log("Tendermint deployed to:", tendermint.address.toLocaleLowerCase())
        console.log("export TENDERMINT_CLIENT=%s", tendermint.address.toLocaleLowerCase())
    })

module.exports = {}
