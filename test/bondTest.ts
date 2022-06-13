import {
     DebondERC3475Instance
} from "../types/truffle-contracts";

const DebondBond = artifacts.require("DebondERC3475");

contract('Bond', async (accounts: string[]) => {

    let bondContract: DebondERC3475Instance

    let DBIT_FIX_6MTH_CLASS_ID: number;
    let USDC_FIX_6MTH_CLASS_ID: number;
    let [owner, governance, issuerEntity, buyer, falseIssuerEntity, DBITAddress, USDCAddress] = accounts;

    it('Initialisation', async () => {
        bondContract = await DebondBond.deployed();

        DBIT_FIX_6MTH_CLASS_ID = 0;
        USDC_FIX_6MTH_CLASS_ID = 1;

    })

    it('Only Governance can create new classes', async () => {
        await bondContract.createClass(DBIT_FIX_6MTH_CLASS_ID, "DBIT", [DBITAddress, 0, 3600 * 24 * 30]);

    })

    it('Only Address with Issuer Role can create new nonces', async () => {
        try {
            await bondContract.createNonce(DBIT_FIX_6MTH_CLASS_ID, 0, [Date.now(), Date.now() + 10000], {from: falseIssuerEntity});
        } catch (e: any) {
            assert(typeof e.reason === 'string')
        }
    })
});
