import {
    DebondBondInstance
} from "../types/truffle-contracts";

const DebondBond = artifacts.require("DebondBond");

contract('Bond', async (accounts: string[]) => {

    let bondContract: DebondBondInstance

    let DBIT_FIX_6MTH_CLASS_ID: number;
    let USDC_FIX_6MTH_CLASS_ID: number;
    let [owner, issuerEntity, buyer, falseIssuerEntity] = accounts;

    it('Initialisation', async () => {
        bondContract = await DebondBond.deployed();

        DBIT_FIX_6MTH_CLASS_ID = 0;
        USDC_FIX_6MTH_CLASS_ID = 1;


        const ISSUER_ROLE = await bondContract.ISSUER_ROLE();
        await bondContract.grantRole(ISSUER_ROLE, issuerEntity, {from: owner})

    })

    it('Only Issuer can create new nonces', async () => {
        try {
            await bondContract.createNonce(DBIT_FIX_6MTH_CLASS_ID, 0, Date.now() + 10000, {from: falseIssuerEntity});
        } catch (e: any) {
            assert(typeof e.reason === 'string')
        }
    })
});
