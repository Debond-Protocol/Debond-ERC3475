import {
    DebondERC3475Instance, ProgressCalculatorInstance
} from "../types/truffle-contracts";

const DebondBond = artifacts.require("DebondERC3475");
const ProgressCalculator = artifacts.require("ProgressCalculator");


interface Transaction {
    classId: number | BN | string;
    nonceId: number | BN | string;
    _amount: number | BN | string;

}

contract('Bond', async (accounts: string[]) => {

    let bondContract: DebondERC3475Instance
    let progressCalculatorContract: ProgressCalculatorInstance

    const DBIT_FIX_6MTH_CLASS_ID = 0;
    const USDC_FIX_6MTH_CLASS_ID = 1;
    const [governance, bank, user1, user2, operator, DBITAddress, USDCAddress] = accounts;

    const now = parseInt(Date.now().toString().substring(-3));

    it('Initialisation', async () => {
        bondContract = await DebondBond.deployed();
        progressCalculatorContract = await ProgressCalculator.deployed();

    })

    it('Should create a new class, only the Bank can do that action', async () => {
        await bondContract.createClass(DBIT_FIX_6MTH_CLASS_ID, "DBIT", [0, 0, 3600 * 24 * 30], {from: bank});
        const classExists = await bondContract.classExists(DBIT_FIX_6MTH_CLASS_ID)
        assert.isTrue(classExists);

    })

    it('Should create a new Nonce, only the Bank can do that action', async () => {
        await bondContract.createNonce(DBIT_FIX_6MTH_CLASS_ID, 0, [now, now], {from: bank});
        const nonceExists = await bondContract.nonceExists(DBIT_FIX_6MTH_CLASS_ID, 0);
        assert.isTrue(nonceExists);
    })

    it('Should update last nonce created, only the Bank can do that action', async () => {
        await bondContract.updateLastNonce(DBIT_FIX_6MTH_CLASS_ID, 0, now, {from: bank});
        const lastCreatedNonceDate = await bondContract.getLastNonceCreated(DBIT_FIX_6MTH_CLASS_ID);
        assert.isTrue(lastCreatedNonceDate["1"] == now);
    })

    it('Should Issue bonds to an account, only the Bank can do that action', async () => {
        const transactions: Transaction[] = [
            {classId: DBIT_FIX_6MTH_CLASS_ID, nonceId: 0, _amount: web3.utils.toWei('3000')}
        ]
        await bondContract.issue(user1, transactions, {from: bank});
        const buyerBalance = await bondContract.balanceOf(user1, DBIT_FIX_6MTH_CLASS_ID, 0);
        assert.isTrue(web3.utils.toWei('3000') == buyerBalance.toString())

    })

    it('Should transfer bonds', async () => {
        const transactions: Transaction[] = [
            {classId: DBIT_FIX_6MTH_CLASS_ID, nonceId: 0, _amount: web3.utils.toWei('1500')}
        ]
        await bondContract.transferFrom(user1, user2, transactions, {from: user1});
        const user1Balance = await bondContract.balanceOf(user1, DBIT_FIX_6MTH_CLASS_ID, 0);
        const user2Balance = await bondContract.balanceOf(user2, DBIT_FIX_6MTH_CLASS_ID, 0);
        assert.isTrue(web3.utils.toWei('1500') == user1Balance.toString())
        assert.isTrue(web3.utils.toWei('1500') == user2Balance.toString())
    })

    it('Should setApproval for an operator', async () => {
        await bondContract.setApprovalFor(operator, DBIT_FIX_6MTH_CLASS_ID, true,{from: user1});
        await bondContract.setApprovalFor(operator, DBIT_FIX_6MTH_CLASS_ID, true,{from: user2});
        const isApproved = await bondContract.isApprovedFor(user1, operator, 0);
        assert.isTrue(isApproved)
    })

    it('Should be able for operator to transfer bonds from user to an other', async () => {
        const transactions: Transaction[] = [
            {classId: DBIT_FIX_6MTH_CLASS_ID, nonceId: 0, _amount: web3.utils.toWei('1500')}
        ]
        await bondContract.transferFrom(user1, user2, transactions, {from: operator});
        const user1Balance = await bondContract.balanceOf(user1, DBIT_FIX_6MTH_CLASS_ID, 0);
        const user2Balance = await bondContract.balanceOf(user2, DBIT_FIX_6MTH_CLASS_ID, 0);
        assert.isTrue('0' == user1Balance.toString())
        assert.isTrue(web3.utils.toWei('3000') == user2Balance.toString())
    })

    it('Should be able to burn bonds from user, only bank can do this action', async () => {

        // we need to set bank as operator for user
        await bondContract.setApprovalFor(bank, DBIT_FIX_6MTH_CLASS_ID, true,{from: user2});

        const transactions: Transaction[] = [
            {classId: DBIT_FIX_6MTH_CLASS_ID, nonceId: 0, _amount: web3.utils.toWei('1000')}
        ]
        await bondContract.burn(user2, transactions, {from: bank});
        const user2Balance = await bondContract.balanceOf(user2, DBIT_FIX_6MTH_CLASS_ID, 0);
        const burnedSupply = await bondContract.burnedSupply(DBIT_FIX_6MTH_CLASS_ID, 0);
        assert.isTrue(web3.utils.toWei('2000') == user2Balance.toString())
        assert.isTrue(web3.utils.toWei('1000') == burnedSupply.toString())
    })

    it('Should be able to redeem bonds from user, only bank can do this action', async () => {

        const transactions: Transaction[] = [
            {classId: DBIT_FIX_6MTH_CLASS_ID, nonceId: 0, _amount: web3.utils.toWei('1000')}
        ]
        // progressCalculator is bank
        await bondContract.setBankAddress(progressCalculatorContract.address);
        await progressCalculatorContract.redeem(user2, transactions);
        const user2Balance = await bondContract.balanceOf(user2, DBIT_FIX_6MTH_CLASS_ID, 0);
        const redeemedSupply = await bondContract.redeemedSupply(DBIT_FIX_6MTH_CLASS_ID, 0);
        assert.isTrue(web3.utils.toWei('1000') == user2Balance.toString())
        assert.isTrue(web3.utils.toWei('1000') == redeemedSupply.toString())
        await bondContract.setBankAddress(bank);

    })

    it('Should give all the nonces per class for a given address', async () => {
        async function getUser1AllToTransactions(event: string): Promise<Transaction[]> {
            return (await bondContract.getPastEvents(event,
                {
                    filter: {
                        _to: user1
                    },
                    fromBlock: 0
                }
            )).map(e => {
                return e.returnValues._transactions as Transaction[];
            }).flat();
        }
        const t = await Promise.all([
            getUser1AllToTransactions('Issue'),
            getUser1AllToTransactions('Transfer')
        ]).then((res: Awaited<Transaction[]>[]) => {
            return res.flat()
        })

        console.log(t);
    })
});

