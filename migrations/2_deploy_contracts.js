const DebondBond = artifacts.require("DebondERC3475");
const ProgressCalculator = artifacts.require("ProgressCalculator");

module.exports = async function (deployer, networks, accounts) {
  const governanceAddress = accounts[0]
  const bankAddress = accounts[1]
  await deployer.deploy(DebondBond, governanceAddress)

  const debondBondContract = await DebondBond.deployed();
  await debondBondContract.setBankAddress(bankAddress, {from: governanceAddress});
  await deployer.deploy(ProgressCalculator, debondBondContract.address);

};
