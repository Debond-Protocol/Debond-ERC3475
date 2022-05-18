const DebondBond = artifacts.require("DebondBond");

module.exports = async function (deployer, networks, accounts) {
  const fakeGovernanceAddress = accounts[0]
  await deployer.deploy(DebondBond, fakeGovernanceAddress)
};
