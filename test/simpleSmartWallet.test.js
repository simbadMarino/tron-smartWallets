const { TronWeb } = require("tronweb");
const chai = require('chai');
const expect = chai.expect;
require('dotenv').config();

//Test Goal: Go over each Requirement of a Smart Wallet Featured contract and perform unit test (Happy path)

/* Contract Requirements:

1. Ideally  less than 150K energy to deploy or less to be competitive with a USDT normal transfer. 
2. Withdraw TRC20 balance function (owner only)
3. Contract must be deployed with 100% Contract ration for energy consumption ratio.
4. Make it flexibile for any TRC20 token

*/

const tronWebOwner = new TronWeb({
    fullHost: process.env.FULL_NODE_NILE,
    privateKey: process.env.PRIVATE_KEY_NILE
});

const tronWebNotOwner = new TronWeb({
    fullHost: process.env.FULL_NODE_NILE,
    privateKey: process.env.PRIVATE_KEY_NILE_NOT_OWNER
});

const contractAddress = process.env.SSWC_CONTRACT_ADDRESS;
const hotWallet = process.env.HOT_WALLET_ADDRESS;
const trc20TokenAddress = process.env.TRC20_TOKEN_ADDRESS;
const ownerAddress = tronWebOwner.address.fromPrivateKey(process.env.PRIVATE_KEY_NILE);

let contract;

describe("SmartWallet Featured Contract Tests", function () {
    this.timeout(30000); // Increase timeout for blockchain transactions
    //Top up vars and constants
    const amount = 5; // Amount of tokens to send
    let decimals = 0;
    let amountToSend = 0;
    before(async function () {
        console.log("-----Setting Up Test Suit-----");
        contract = await tronWebOwner.contract().at(contractAddress); //Get Smart Wallet contract object ABI as contract owner 
        contractNotOwner = await tronWebNotOwner.contract().at(contractAddress); //Get Smart Wallet contract object ABI as non contract owner

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
            const txID = await contractNotOwner.withdrawToMainWallet(trc20TokenAddress, hotWallet, amountToSend).send();
            console.log("Transaction hash: ", txID);
            await tronWebOwner.trx.getUnconfirmedTransactionInfo(txID);
            const trc20WithdrawalResult = await tronWebOwner.trx.getTransaction(txID);
            console.log("TRC20 Withdrawal result: ", trc20WithdrawalResult.ret[0].contractRet);
            expect(trc20WithdrawalResult.ret[0].contractRet).to.be.equal("REVERT");
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
            const txID = await contract.withdrawToMainWallet(trc20TokenAddress, hotWallet, amountToSend).send();
            console.log("Transaction hash: ", txID);
            await tronWebOwner.trx.getUnconfirmedTransactionInfo(txID);
            const trc20WithdrawalResult = await tronWebOwner.trx.getTransaction(txID);
            console.log("TRC20 Withdrawal result: ", trc20WithdrawalResult.ret[0].contractRet);
            expect(trc20WithdrawalResult.ret[0].contractRet).to.be.equal("SUCCESS");
        } else {
            console.warn("Skipping TRC20 withdrawal test: No tokens in contract.");
        }
    });

});
