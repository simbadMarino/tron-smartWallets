//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/*
TRON Smart Wallet Contract with TRX withdrawals enabled (SSWTC):

Note, This Smart Wallet provides the least features to decrease deployment cost as much as possible for Single Use wallets, improving security by enabling TRX withdrawals.

Goal: Reduce energy delegation and USDT transfer complexity for wallet management / payments platforms,eCommerce like Telegram Wallets, CEX or similar.



Background:
TRON is heavily used by custodial wallet, eCommerce, payments and  gift cards services due to its flexibility to offer gas-less / reduced fees transactions by staking TRX for energy.
This has considerably supported TRON's growth on USDT txns, however, due to recent TRX prize appreciation we need to explorer further ways to optimize platforms 
transactions and reduce overall on-chain fees by flexing:

1) TRON's resource model from user perspective (Staking, delegating, renting)
2) TRON's resource model from developer/bussines owner perspective (Contract Owner energy pool) 

Identified Use Cases:

    a) eCommerce or payments platform workflow: 
        1. ecommerce platforms creates a new account for  customer to deposit USDT/TRX/Any TRC20 --> Replaced by a Simple Smart Wallet creation 
        2. User deposits the payment, this will come with a network fee --> By using the SmartWallet approach the platform can sponsor deposits // TO-DO: Explore solutions for this. 
        3. eCommerce delegate energy OR send TRX to be burned towards that account  --> Smart wallet shares contract owner energy pool, no need to delegate or send TRX to pay for fees
        5. eCommerce transfers back customer deposited tokens to Dev/Hot wallet. --> eCommerce will trigger the Withdraw function to get customer payments to their hot wallet/omni wallet.
        4. Payment is confirmed

Contract Requirements:

1. Ideally  less than 150K energy to deploy or less to be competitive with a USDT normal transfer. 
2. Withdraw TRC20 balance function (Write, owner only)
3. Contract must be deployed with 100% Contract ration for energy consumption ratio.
4. Make it flexibile for any TRC20 token
5. TRX withdrawal option for security and flexibility reasons.

Contract Requirements Notes after Testnet deployment:

1. Requirement Partially Achieved: After trials this contract needs 219K energy (as of Jan 29th 2025), still useful for non-throw-away use cases like custodial wallets in Telegram or CEX)
    1.a) Optimizations is neded to reduce cost of deployment. Tested with Solc optimizer enabled, 200 runs. 
    1.b) Deployment cost: 219K energy
    1.c) USDT withdrawal to Hot wallet cost: Approx. 65K energy per transfer
    1.d) This approach offers platforms the flexibility to balance transfer load to optimize energy pool availability, once balance is in the bussines owner SSWC 
    and owner energy is below a certain threshold owner can optionally wait to transfer that balance to its own hot-wallet/omni wallet/cold-wallet until energy pool is recovered.
2. Requirement Achieved 
3. Requirement Achieved
4. Requirement Achieved (No getBalance from IRC20, need manual balance input)
5. Requirement Achieved

TO-DO:
-Explore additional ways to reduce deployment cost

*/

// Define an interface for TRC20 tokens (similar to ERC20 in Ethereum)
interface ITRC20 {
    // Function to transfer tokens to a recipient
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);
}

// Smart contract for handling TRC20 token and TRX transactions
contract SmartWalletTRC20TRX {
    // Address of the contract owner
    address public owner;

    // Events to log transfer results and TRX withdrawals
    event TransferFailed(address _hotWallet, uint256 withdrawAmount);
    event TransferSuccess(address _hotWallet, uint256 withdrawAmount);
    event TRXWithdrawn(address indexed recipient, uint256 amount);

    // Modifier to restrict function access to only the contract owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner may call function");
        _;
    }

    // Constructor sets the contract deployer as the owner
    constructor() {
        owner = payable(msg.sender);
    }

    // Function to withdraw TRC20 tokens from the contract to a hot wallet
    function withdrawToMainWallet(
        address _trc20Token, // Address of the TRC20 token contract
        address _hotWallet, // Destination address for withdrawal
        uint256 _smartWalletBalance // Amount of tokens to withdraw
    ) external onlyOwner {
        // Only the owner can call this function
        ITRC20 trc20Token = ITRC20(_trc20Token);

        // Attempt to transfer the specified amount of tokens
        bool success = trc20Token.transfer(_hotWallet, _smartWalletBalance);

        // Emit appropriate event based on the transfer success or failure
        if (!success) {
            emit TransferFailed(_hotWallet, _smartWalletBalance);
        } else {
            emit TransferSuccess(_hotWallet, _smartWalletBalance);
        }
    }

    // Function to withdraw TRX (native TRON currency) from the contract
    function withdrawTRX(
        uint256 amount, // Amount of TRX to withdraw
        address payable _address // Address to receive the TRX
    ) external onlyOwner {
        // Only the owner can call this function
        _address.transfer(amount);

        // Emit an event for tracking the withdrawal
        emit TRXWithdrawn(owner, amount);
    }
}
