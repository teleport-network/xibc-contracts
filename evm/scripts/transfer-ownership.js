// scripts/transfer-ownership.js
async function main () {
    const gnosisSafe = '0x63f7Ebe743983d020004405D91D4e62Da18A998C';
  
    console.log('Transferring ownership of ProxyAdmin...');
    // The owner of the ProxyAdmin can upgrade our contracts
    await upgrades.admin.transferProxyAdminOwnership(gnosisSafe);
    console.log('Transferred ownership of ProxyAdmin to:', gnosisSafe);
  }
  
  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });