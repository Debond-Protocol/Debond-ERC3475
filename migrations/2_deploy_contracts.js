const DebondBond = artifacts.require("DebondBond");

module.exports = async function (deployer, accounts) {

  await deployer.deploy(DebondBond)
};
