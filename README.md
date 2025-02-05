# TRON Tailored Smart Wallets

This repo is a colllection of Smart Wallet Contracts and Account Abstaction related utilities tailored for TRON.

### What is a Smart Wallet or Smart Contract Account?

We can start by comparing a normal TRON accout, commonly known as EOA (Externally Owned Account)  vs a Smart Wallet.

An EOA account is your default TRON account, which is linked to a private key or seedphrase, meaning you hold full ownership and responsability for your account resources security.

A Smart Wallet is in escense  a simple Smart Contract which can hold TRX and crypto tokens and assigns a wallet manager to control certain secuirty features like asset withdrawal, ownership change, etc.

So, if an EOA in TRON can even have multisign capabilities by default, why would you need a Smart Wallet?

1. **Resources Inheritance:** In TRON, the contract deployer can assign itself as a paymaster with configurable sponsorship ratio (0% to 100%)
2. **Eliminate Account activation fixed cost:** In TRON you need 1.1 TRX to activate a need EOA, creating Smart Wallets could be free provided the contract deployer has enough energy.
3. **Energy delegation simplicity for payments:** Instead of dynamically delegating resources to individual wallets for assets withdrawals, you can delegate energy to a single wallet (depoyer account) and enjoy sponsored transactions for all, reducing Bandwidth costs and infrastructure complexity.

## Project Structure

```
.
├── README.md
├── build            //This folder holds contract build data after compiling
├── contracts    //Smart wallet examples
│   ├── SimpleSmartWallet.sol
│   ├── SmartWalletFeatured.sol
│   └── SmartWalletTRC20TRX.sol
├── migrations    //Contract deployment scripts
│   ├── 1_deploy_SSWC.js
│   ├── 2_deploy_SWTRXC.js
│   └── 3_deploy_SWFEAT.js
├── package.json
├── test                //contracts test scripts
│   ├── simpleSmartWallet.test.js
│   ├── smartWalletFeatured.test.js
│   └── smartWalletTRC20TRX.test.js
├── tronbox-config.js
├── tronbox-evm-config.js
├── tronbox.js      //tronbox setup file
└── yarn.lock
```

## Smart Wallets Contracts

### Simple Smart Wallet Contract (SSWC)

Goal: Reduce energy delegation and USDT transfer complexity for wallet management / payments platforms, eCommerce like Telegram Wallets, CEX or similar.

Note, This Smart Wallet provides the least features to decrease deployment cost as much as possible for Single Use wallets.

### Smart Wallet TRC20 TRX (SWTRXC)

Goal: Reduce energy delegation and USDT transfer complexity for wallet management / payments platforms, eCommerce like Telegram Wallets, CEX or similar.

Note, This Smart Wallet provides the least features to decrease deployment cost as much as possible for Single Use wallets, improving security by enabling TRX withdrawals.

### Smart Wallet Featured (SWFEAT)

Goal: Reduce energy delegation and USDT transfer complexity for wallet management / payments platforms,eCommerce like Telegram Wallets, CEX or similar while keeping a set of useful functions and features.

Note, This Smart Wallet provides the some extra convinience features to make user and bussines experience as smooth as possible for regular usage wallets.

## Setup and Deployment

### 1. Setup and Config

```bash
git clone https://github.com/simbadMarino/tron-smartWallets.git # Clone this repo
cp .env.sample .env #Create your own .env file and fill it out to configure deployment environment
yarn install | npm install  # Install dependencies
```

### 2. SC Deployment

```bash
tronbox compile  #Compile your Smart Contracts using tronbox
tronbox migrate --network nile  #Deploy the active contracts under the migrations directory, modify the prefered deployment network as needed
```

### 3. Testing

You can easily test your deployed smart contracts with chai, currently a test suit per contract was created.

Before running the following tests make sure you have filled-out the deployed contrac addresses as well as the TRC20 token you will be using for the tests in your .env file

Note: Extending test cases is advised if you are deploying this Smart wallets to production.

```bash
npx mocha test/simpleSmartWallet.test.js    #Run the simpleSmartWallet contract test suit 
npx mocha test/smartWalletTRC20TRX.test.js  #Run the smartWalletTRC20TRX contract test suit
npx mocha test/smartWalletFeatured.test.js  #Run the smartWalletFeatured contract test suit
```

### Conclusion

When it comes to operational simplicity, smart wallets on TRON are a great way to avoid the need of constantly delegating resources and/or activating accounts in behalve of third parties. The solutions proposed here address a common use case for online payments and general wallet management.
