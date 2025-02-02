const { TronWeb } = require("tronweb");
const chai = require('chai');
const expect = chai.expect;
require('dotenv').config();

//Test Goal: Go over each Requirement of a Smart Wallet Featured contract and perform unit test (Happy path)

/* Contract Requirements:

1. Ideally  less than 250k energy to deploy or less. --> Not covered
2. Withdraw TRC20 balance function (Write, owner only)
3. Contract must be deployed with 100% Contract ration for energy consumption ratio. --> Not covered
4. Make it flexibile for any TRC20 token --> Not covered
5. TRX withdrawal option for security and flexibility reasons.
6. Contract is able to change owner if needed
7. Contract owner is publicly visible.

*/

const tronWebOwner = new TronWeb({
    fullHost: process.env.FULL_NODE_NILE,
    privateKey: process.env.PRIVATE_KEY_NILE
});

const tronWebNotOwner = new TronWeb({
    fullHost: process.env.FULL_NODE_NILE,
    privateKey: process.env.PRIVATE_KEY_NILE_NOT_OWNER
});

const contractAddress = process.env.SWFEAT_CONTRACT_ADDRESS;
const hotWallet = process.env.HOT_WALLET_ADDRESS;
const trc20TokenAddress = process.env.TRC20_TOKEN_ADDRESS;
const ownerAddress = tronWebOwner.address.fromPrivateKey(process.env.PRIVATE_KEY_NILE);

let contract;

describe(" SmartWallet Featured Contract Tests", function () {
    this.timeout(30000); // Increase timeout for blockchain transactions
    //Top up vars and constants
    const amount = 5; // Amount of tokens to send
    let decimals = 0;
    let amountToSend = 0;
    before(async function () {
        console.log("-----Setting Up Test Suit-----");
        contract = await tronWebOwner.contract().at(contractAddress);
        contractNotOwner = await tronWebNotOwner.contract().at(contractAddress);

        //Top up the Smart Wallet contract with some TRC20 tokens
        const trc20contract = await tronWebOwner.contract().at(trc20TokenAddress); //Get Smart Wallet contract object ABI as contract owner 
        decimals = await trc20contract.methods.decimals().call();
        amountToSend = BigInt(amount) * BigInt(10) ** BigInt(decimals);
        console.log("Sending %d tokens to Smart Wallet...", amount);
        const transactiontrc20 = await trc20contract.methods.transfer(
            contractAddress,
            amountToSend
        ).send();
        console.log(transactiontrc20);

        //Top up Smart Wallet contract with some TRX before the tests start
        trxAmount = tronWebNotOwner.toSun(1); // 1 TRX
        console.log("Sending %d TRX to Smart Wallet: ", trxAmount / 1000000);
        const txn = await tronWebNotOwner.trx.sendTransaction(contractAddress, trxAmount)
        console.log("Transaction executed, result: ", txn.result);
        console.log("-----End of Setup-----");

    });


    it("should verify contract ownership", async function () {
        console.log("***TC_1) Checking Owner is Public in Contract...")
        let contractOwner = await contract.owner().call();
        contractOwner = TronWeb.address.fromHex(contractOwner);
        console.log("Nile Wallet Configured Address is %s \nContract Owner from Contract is: %s ", ownerAddress, contractOwner)
        expect(contractOwner).to.equal(ownerAddress);
    });

    it("should fail if non-owner tries to withdraw TRC20 tokens", async function () {
        console.log("***TC_2) Checking TRC20 Withdrawals are forbidden for non-contract-owners...")
        const tokenContract = await tronWebNotOwner.contract().at(trc20TokenAddress);
        const initialBalance = await tokenContract.balanceOf(contractAddress).call();
        console.log("TRC20 token Address is: ", trc20TokenAddress);
        console.log("TRC20 token balance is: ", initialBalance);
        if (parseInt(initialBalance) > 0) {
            const txID = await contractNotOwner.withdrawToMainWallet(trc20TokenAddress, hotWallet).send();
            console.log("Transaction hash: ", txID);
            await tronWebOwner.trx.getUnconfirmedTransactionInfo(txID);
            const trc20WithdrawalResult = await tronWebOwner.trx.getTransaction(txID);
            console.log("TRC20 Withdrawal result: ", trc20WithdrawalResult.ret[0].contractRet);
            expect(trc20WithdrawalResult.ret[0].contractRet).to.be.equal("REVERT"); // Transaction hash
        } else {
            console.warn("Skipping TRC20 withdrawal test for non-owners: No tokens in contract.");
        }
    });

    it("should withdraw TRC20 tokens as owner", async function () {
        console.log("***TC_3) Checking TRC20 Withdrawals are allowed for contract-owner...")
        const tokenContract = await tronWebOwner.contract().at(trc20TokenAddress);
        const initialBalance = await tokenContract.balanceOf(contractAddress).call();
        console.log("TRC20 token Address is: ", trc20TokenAddress);
        console.log("TRC20 token balance is: ", initialBalance);
        if (parseInt(initialBalance) > 0) {
            const txID = await contract.withdrawToMainWallet(trc20TokenAddress, hotWallet).send();
            console.log("Transaction hash: ", txID);
            await tronWebOwner.trx.getUnconfirmedTransactionInfo(txID);
            const trc20WithdrawalResult = await tronWebOwner.trx.getTransaction(txID);
            console.log("TRC20 Withdrawal result: ", trc20WithdrawalResult.ret[0].contractRet);
            expect(trc20WithdrawalResult.ret[0].contractRet).to.be.equal("SUCCESS"); // Transaction hash
        } else {
            console.warn("Skipping TRC20 withdrawal test: No tokens in contract.");
        }
    });
    it("should fail withdrawal TRX as for non owner", async function () {
        console.log("***TC_4) Checking TRX Withdrawals are NOT allowed for non contract-owner...")
        try {

            const txID = await contractNotOwner.withdrawTRX(trxAmount, hotWallet).send();
            console.log("Transaction hash: ", txID);
            await tronWebOwner.trx.getUnconfirmedTransactionInfo(txID);
            const withdrawalResult = await tronWebNotOwner.trx.getTransaction(txID);
            console.log("TRX Withdrawal result: ", withdrawalResult.ret[0].contractRet);
            expect(withdrawalResult.ret[0].contractRet).to.be.equal("REVERT");
        } catch (error) {
            expect.fail("TRX withdrawal failed: " + error.message);
        }
    });

    it("should withdraw TRX as owner", async function () {
        console.log("***TC_5) Checking TRX Withdrawals are allowed for contract-owner...")

        try {
            const txID = await contract.withdrawTRX(trxAmount, hotWallet).send();
            console.log("Transaction hash: ", txID);
            await tronWebOwner.trx.getUnconfirmedTransactionInfo(txID);
            const withdrawalResult = await tronWebOwner.trx.getTransaction(txID);
            console.log("TRX Withdrawal result: ", withdrawalResult.ret[0].contractRet);
            expect(withdrawalResult.ret[0].contractRet).to.be.equal("SUCCESS");
        } catch (error) {
            expect.fail("TRX withdrawal failed: " + error.message);
        }
    });

    it("should be able to change owner as owner", async function () {
        console.log("***TC_6) Checking it can change ownership...");
        try {
            const txID = await contract.changeOwner(ownerAddress).send();
            console.log("Transaction hash: ", txID);
            const changeOwnerResult = await tronWebOwner.trx.getTransaction(txID);
            console.log("Change Owner result: ", changeOwnerResult.ret[0].contractRet);
            expect(changeOwnerResult.ret[0].contractRet).to.be.equal("SUCCESS");
        }
        catch (error) {
            expect.fail("Could not change owner as owner: " + error.message);
        }
    });
    it("should NOT BE ABLE to change owner as NOT Owner", async function () {
        console.log("***TC_7) Checking non-owner cannot change ownership...");
        try {
            const txID = await contractNotOwner.changeOwner(ownerAddress).send();
            console.log("Transaction hash: ", txID);
            const changeOwnerResult = await tronWebOwner.trx.getTransaction(txID);
            console.log("Change Owner result: ", changeOwnerResult.ret[0].contractRet);
            expect(changeOwnerResult.ret[0].contractRet).to.be.equal("REVERT");
        }
        catch (error) {
            expect.fail("Something went wrong: " + error.message);
        }
    });
});
