//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/*
TRON Smart Wallet Contract with TRX withdrawals enabled and extra convenience features (SSWTC):

Note, This Smart Wallet provides the some extra convinience features to make user and bussines experience as smooth as possible for regular usage wallets.

Goal: Reduce energy delegation and USDT transfer complexity for wallet management / payments platforms,eCommerce like Telegram Wallets, CEX or similar while keeping full features.



Background:
TRON is heavily used by custodial wallet, eCommerce, payments and  gift cards services due to its flexibility to offer gas-less / reduced fees transactions by staking TRX for energy.
This has considerably supported TRON's growth on USDT txns, however, due to recent TRX prize appreciation we need to explorer further ways to optimize platforms 
transactions and reduce overall on-chain fees by flexing:

1) TRON's resource model from user perspective (Staking, delegating, renting)
2) TRON's resource model from developer/bussines owner perspective (Contract Owner energy pool) 

Identified Use Cases:
This Smart Contract works best for regularly used Smart wallets, not for single use due to higher deployment cost.
    a) eCommerce or payments workflow: 
        1. ecommerce platforms creates a new account for  customer to deposit USDT/TRX/Any TRC20 --> Replaced by a Simple Smart Wallet creation 
        2. User deposits the payment, this will come with a network fee --> By using the SmartWallet approach the platform can sponsor deposits // TO-DO: Explore solutions for this. 
        3. eCommerce delegate energy OR send TRX to be burned towards that account  --> Smart wallet shares contract owner energy pool, no need to delegate or send TRX to pay for fees
        5. eCommerce transfers back customer deposited tokens to Dev/Hot wallet. --> eCommerce will trigger the Withdraw function to get customer payments to their hot wallet/omni wallet.
        4. Payment is confirmed

Contract Requirements:

1. Ideally  less than 250k energy to deploy or less.
2. Withdraw TRC20 balance function (Write, owner only)
3. Contract must be deployed with 100% Contract ration for energy consumption ratio.
4. Make it flexibile for any TRC20 token
5. TRX withdrawal option for security and flexibility reasons.
6. Contract is able to change owner if needed

Contract Requirements Notes after Testnet deployment:

1. Requirement Partially Achieved: After trials this contract needs 255k energy (as of Jan 30th 2025), still useful for non-throw-away use cases like custodial wallets in Telegram or CEX)
    1.a) Optimizations is neded to reduce cost of deployment. Tested with Solc optimizer enabled, 200 runs. 
    1.b) Deployment cost: 255K energy
    1.c) USDT withdrawal to Hot wallet cost: Approx. 65K energy per transfer
    1.d) This approach offers platforms the flexibility to balance transfer load to optimize energy pool availability, once balance is in the bussines owner SSWC 
    and owner energy is below a certain threshold owner can optionally wait to transfer that balance to its own hot-wallet/omni wallet/cold-wallet until energy pool is recovered.
2. Requirement Achieved 
3. Requirement Achieved
4. Requirement Achieved (Automatically withdraw all balance )
5. Requirement Achieved


TO-DO:
-Explore additional ways to reduce deployment cost

*/

interface ITRC20 {
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function balanceOf(address account) external view returns (uint256);
}

contract SmartWalletFeatured {
    address public owner;
    event TransferFailed(address _hotWallet, uint256 withdrawAmount);
    event TransferSuccess(address _hotWallet, uint256 withdrawAmount);
    event TRXWithdrawn(address indexed recipient, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner may call function");
        _;
    }

    constructor() {
        owner = payable(msg.sender);
    }

    function withdrawToMainWallet(
        address _trc20Token,
        address _hotWallet
    ) external onlyOwner {
        ITRC20 trc20Token = ITRC20(_trc20Token);
        uint256 smartWalletBalance = trc20Token.balanceOf(address(this));
        bool success = trc20Token.transfer(_hotWallet, smartWalletBalance - 1); //Transfer ALL balance but a minimum amount of the TRC20 token so its cheaper to deposit for users next time. This must effectively prevent the wallet to reach a 0 balance

        if (!success) {
            emit TransferFailed(_hotWallet, smartWalletBalance);
        } else emit TransferSuccess(_hotWallet, smartWalletBalance);
    }

    function withdrawTRX(
        uint256 amount,
        address payable _address
    ) external onlyOwner {
        _address.transfer(amount);
        emit TRXWithdrawn(owner, amount);
    }

    function changeOwner(address _newOwnerAddress) external onlyOwner {
        owner = _newOwnerAddress;
    }
}
