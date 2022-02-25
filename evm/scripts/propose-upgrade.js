// scripts/propose-upgrade.js
const { defender } = require("hardhat");

async function main() {
  const proxyAddress = '0x9793bcba810c4ca546ad53607001c0cefd7fce1c';

  const upgradeFac = await ethers.getContractFactory("MockTransfer");
  console.log("Preparing proposal...");
  const proposal = await defender.proposeUpgrade(proxyAddress, upgradeFac);
  console.log("Upgrade proposal created at:", proposal.url);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  })