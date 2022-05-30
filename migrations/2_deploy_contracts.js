const DebondBond = artifacts.require("DebondBond");

module.exports = async function (deployer, networks, accounts) {
  const governanceAddress = accounts[1]
  await deployer.deploy(DebondBond, governanceAddress)
};
