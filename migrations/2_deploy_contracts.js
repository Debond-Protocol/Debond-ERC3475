const DebondBond = artifacts.require("DebondERC3475");

module.exports = async function (deployer, networks, accounts) {
  const bankAddress = accounts[0]
  const governanceAddress = accounts[1]
  await deployer.deploy(DebondBond, governanceAddress)

  const debondBondContract = await DebondBond.deployed();
  await debondBondContract.setBankAddress(bankAddress, {from: governanceAddress});
};
