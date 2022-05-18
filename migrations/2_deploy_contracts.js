const DebondBond = artifacts.require("DebondBond");

module.exports = async function (deployer, networks, accounts) {
  await deployer.deploy(DebondBond)
};
