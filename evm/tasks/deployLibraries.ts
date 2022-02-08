import "@nomiclabs/hardhat-web3"
import { task } from "hardhat/config"

task("deployLibraries", "Deploy All Libraries")
    .setAction(async (taskArgs, hre) => {
        const ClientStateCodec = await hre.ethers.getContractFactory('ClientStateCodec')
        const clientStateCodec = await ClientStateCodec.deploy()
        await clientStateCodec.deployed()

        const ConsensusStateCodec = await hre.ethers.getContractFactory('ConsensusStateCodec')
        const consensusStateCodec = await ConsensusStateCodec.deploy()
        await consensusStateCodec.deployed()

        const ProofCodec = await hre.ethers.getContractFactory('ProofCodec')
        const proofCodec = await ProofCodec.deploy()
        await proofCodec.deployed()

        const LightClientVerify = await hre.ethers.getContractFactory('LightClientVerify')
        const lightClientVerify = await LightClientVerify.deploy()
        await lightClientVerify.deployed()
        
        const LightClientGenValHash = await hre.ethers.getContractFactory('LightClientGenValHash')
        const lightClientGenValHash = await LightClientGenValHash.deploy()
        await lightClientGenValHash.deployed()

        const Verifier = await hre.ethers.getContractFactory(
            'Verifier',
            { libraries: { ProofCodec: proofCodec.address, } }
        )
        const verifierLib = await Verifier.deploy()
        await verifierLib.deployed()

        console.log("ClientStateCodec deployed to:", clientStateCodec.address.toLocaleLowerCase())
        console.log("ConsensusStateCodec deployed to:", consensusStateCodec.address.toLocaleLowerCase())
        console.log("ProofCodec deployed to:", proofCodec.address.toLocaleLowerCase())
        console.log("Verifier deployed to:", verifierLib.address.toLocaleLowerCase())
        console.log("LightClientVerify deployed to:", lightClientVerify.address.toLocaleLowerCase())
        console.log("LightClientGenValHash deployed to:", lightClientGenValHash.address.toLocaleLowerCase())

        console.log("export CLIENT_STATE_CODEC_ADDRESS=%s", clientStateCodec.address.toLocaleLowerCase())
        console.log("export CONSENSUS_STATE_CODEC_ADDRESS=%s", consensusStateCodec.address.toLocaleLowerCase())
        console.log("export PROOF_CODEC_ADDRESS=%s", proofCodec.address.toLocaleLowerCase())
        console.log("export VERIFIER_ADDRESS=%s", verifierLib.address.toLocaleLowerCase())
        console.log("export LIGHT_CLIENT_VERIFY_ADDRESS=%s", lightClientVerify.address.toLocaleLowerCase())
        console.log("export LIGHT_CLIENT_GEN_VALHASH_ADDRESS=%s", lightClientGenValHash.address.toLocaleLowerCase())
    })

module.exports = {}
