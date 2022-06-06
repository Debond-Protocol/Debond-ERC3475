import {
    DebondBondInstance
} from "../types/truffle-contracts";

const DebondBond = artifacts.require("DebondBond");

contract('Bond', async (accounts: string[]) => {

    let bondContract: DebondBondInstance

    const DBIT_FIX_6MTH_CLASS_ID = 0;
    const DBIT_FLOAT_6MTH_CLASS_ID = 1;
    const USDC_FIX_6MTH_CLASS_ID = 2;
    const USDC_FLOAT_6MTH_CLASS_ID = 3;
    const SIX_MONTHS = 3600 * 24 * 180;
    const buyingAmount = web3.utils.toWei('10000', 'ether');
    const USDCNonces = [
        {nonceId: 1, issue: "both"},
        {nonceId: 3, issue: "fix"},
        {nonceId: 4, issue: "float"},
        {nonceId: 5, issue: "float"},
        {nonceId: 6, issue: "float"},
        {nonceId: 7, issue: "both"},
        {nonceId: 8, issue: "fix"},
        {nonceId: 9, issue: "both"},
        {nonceId: 10, issue: "float"},
        {nonceId: 11, issue: "fix"},
        {nonceId: 15, issue: "both"},
        {nonceId: 17, issue: "fix"},
        {nonceId: 20, issue: "fix"},
        {nonceId: 21, issue: "fix"},
        {nonceId: 22, issue: "float"},
        {nonceId: 23, issue: "float"},
        {nonceId: 25, issue: "fix"},
        {nonceId: 30, issue: "both"},
        {nonceId: 31, issue: "float"},
        {nonceId: 32, issue: "float"},
        {nonceId: 33, issue: "float"},
        {nonceId: 35, issue: "fix"},
        {nonceId: 38, issue: "float"},
        {nonceId: 40, issue: "fix"},
        {nonceId: 51, issue: "fix"}
        ]

    const [owner, governance, issuerEntity, buyer, falseIssuerEntity, DBITAddress, USDCAddress] = accounts;

    it('Initialisation', async () => {
        bondContract = await DebondBond.deployed();


        const ISSUER_ROLE = await bondContract.ISSUER_ROLE();
        await bondContract.grantRole(ISSUER_ROLE, issuerEntity, {from: owner})

        await bondContract.createClass(DBIT_FIX_6MTH_CLASS_ID, "DBIT", 0, DBITAddress, SIX_MONTHS, {from: governance});
        await bondContract.createClass(DBIT_FLOAT_6MTH_CLASS_ID, "DBIT", 1, DBITAddress, SIX_MONTHS, {from: governance});
        await bondContract.createClass(USDC_FIX_6MTH_CLASS_ID, "USDC", 0, USDCAddress, SIX_MONTHS, {from: governance});
        await bondContract.createClass(USDC_FLOAT_6MTH_CLASS_ID, "USDC", 1, USDCAddress, SIX_MONTHS, {from: governance});

    })

    it('Issuing multiple USDC bonds', async () => {
        for (const n of USDCNonces) {
            if (n.issue === "fix") {
                await bondContract.createNonce(USDC_FIX_6MTH_CLASS_ID, n.nonceId, Date.now() + SIX_MONTHS, {from: issuerEntity});
                await bondContract.issue(buyer, USDC_FIX_6MTH_CLASS_ID, n.nonceId, buyingAmount,{from: issuerEntity});
            }
            if (n.issue === "float") {
                await bondContract.createNonce(USDC_FLOAT_6MTH_CLASS_ID, n.nonceId, Date.now() + SIX_MONTHS, {from: issuerEntity});
                await bondContract.issue(buyer, USDC_FLOAT_6MTH_CLASS_ID, n.nonceId, buyingAmount,{from: issuerEntity});
            }
            if (n.issue === "both") {
                await bondContract.createNonce(USDC_FIX_6MTH_CLASS_ID, n.nonceId, Date.now() + SIX_MONTHS, {from: issuerEntity});
                await bondContract.createNonce(USDC_FLOAT_6MTH_CLASS_ID, n.nonceId, Date.now() + SIX_MONTHS, {from: issuerEntity});
                await bondContract.issue(buyer, USDC_FIX_6MTH_CLASS_ID, n.nonceId, buyingAmount,{from: issuerEntity});
                await bondContract.issue(buyer, USDC_FLOAT_6MTH_CLASS_ID, n.nonceId, buyingAmount,{from: issuerEntity});
            }
        }

    })

    it('USDC Bonds Total Supply', async () => {
        console.log(USDCNonces.length, (await bondContract.tokenTotalSupply(USDCAddress)).toString())
        assert.equal((await bondContract.tokenTotalSupply(USDCAddress)).toString(), (web3.utils.toWei((10000 * 30).toString())))
    })

    it('USDC Bsum(n)', async () => {
        console.log((await bondContract.tokenSupplyAtNonce(USDCAddress,1)).toString())
        console.log((await bondContract.supplyIssuedOnPeriod(USDCAddress,25, 51)).div(web3.utils.toBN(51 - 25)).toString())
    })
});
