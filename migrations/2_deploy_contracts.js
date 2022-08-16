const DebondBond = artifacts.require("DebondERC3475");
const ProgressCalculator = artifacts.require("ProgressCalculator");
const LiquidityRedeemable = artifacts.require("LiquidityRedeemable");

module.exports = async function (deployer, networks, accounts) {
  const governanceAddress = accounts[0]
  const bondManagerAddress = accounts[1]
  await deployer.deploy(DebondBond, governanceAddress)

  const debondBondContract = await DebondBond.deployed();
  await debondBondContract.setBondManagerAddress(bondManagerAddress, {from: governanceAddress});
  await deployer.deploy(ProgressCalculator, debondBondContract.address);
  await deployer.deploy(LiquidityRedeemable, debondBondContract.address);
  const liquidityRedeemableContract = await LiquidityRedeemable.deployed();
  await debondBondContract.setRedeemableAddress(liquidityRedeemableContract.address, {from: governanceAddress});


};
