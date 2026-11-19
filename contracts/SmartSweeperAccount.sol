//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**@dev TRON USDT "Sweeping" Contract, TIP-1167 Ready


Goal: Reduce energy delegation and USDT transfer complexity for wallet management / payments platforms while executing "USDT Sweeping"

Background:
TRON is heavily used by custodial wallet services, eCommerce, payments and  gift cards services due to its flexibility to offer gas-less / reduced fees transactions by staking TRX for energy.
This contract is meant to be used as an implemtation contract for TIP-1167 minimal proxy contracts



Contract Requirements:

1. Initial deployment is below 400k energy and subsequent clone deployments should be as cheap as possible.
2. Contract is restricted to Owner on critical functions
3. Withdraw any TRC20 standard token balance 
4. Contract must be deployed with 100% Contract ratio for energy consumption ratio.
5. Make it flexibile for any TRC20 token including non standard tokens like USDT
6. TRX withdrawal option for security and flexibility reasons (for both the implementation and clone contracts).

Contract Requirements Notes after Testnet deployment:

1. Requirement Partially Achieved: After trials this contract needs 525k energy OR 474k energy(via-ir) (as of June 26th 2026), Clone deployments using owner address as arg takes 50k energy per new contract, still useful for non-throw-away use cases like custodial wallets, CEX and PSPs)
2. Requirement Achieved 
3. Requirement Achieved
4. Requirement Achieved
5. Requirement Achieved 
6. Requirement Achieved




*/
import "@openzeppelin/tron-contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/tron-contracts/proxy/Clones.sol";
import "@openzeppelin/tron-contracts/token/TRC20/ITRC20.sol";
import "@openzeppelin/tron-contracts/token/TRC20/utils/SafeTRC20.sol";
import {Address} from "@openzeppelin/tron-contracts/utils/Address.sol";

// Smart contract for a more advanced smart wallet
contract SmartSweeperAccount is ReentrancyGuard {
    using SafeTRC20 for ITRC20;
    using Address for address payable;

    /**
     *@notice We need a safety mechanism to recover funds in case users transfer assets to implementation contract instead of clones by mistake, thus the _rescuer is created
     * */
    address private immutable _rescuer;

    constructor() {
        _rescuer = msg.sender;
    }

    // Events to log different actions in the contract
    event SweepedTRX(address indexed recipient, uint256 amount);
    event SweepedToken(address indexed token, address to, uint256 amount);

    /**@dev Address of the wallet's owner (passed trough immutable args when deployed). No need to initialize owner, saves some post deployment energy
     *@notice Implementation contract address owner wont match
     * */
    function owner() public view returns (address) {
        bytes memory args = Clones.fetchCloneArgs(address(this)); // Reads appended args
        require(args.length >= 20, "Invalid args length");

        address result;
        assembly {
            result := mload(add(args, 32)) // Read from offset 32
            result := shr(96, result) // Shift to get address
        }
        return result;
    }

    // Modifier to restrict certain functions to only the contract owner
    modifier onlyOwner() {
        require(msg.sender == owner(), "Only owner may call function");
        _;
    }

    function rescueTokens(address _token, address _to) external {
        require(msg.sender == _rescuer, "Not rescuer");
        // ensure this only works on the implementation, not on clones
        require(
            address(this).code.length > 100,
            "Only callable on implementation contract"
        );
        ITRC20 token = ITRC20(_token);
        uint256 balance = token.balanceOf(address(this));
        if (balance == 0) return;
        token.transfer(_to, balance);
    }

    function rescueTRX(address payable _to) external {
        require(msg.sender == _rescuer, "Not rescuer");
        // ensure this only works on the implementation, not on clones
        require(
            address(this).code.length > 100,
            "Only callable on implementation contract"
        );
        uint256 balance = address(this).balance;
        if (address(this).balance == 0) return;
        _to.sendValue(balance);
    }
    //

    // Function to withdraw USDT tokens to a hot wallet
    function sweepUSDT(
        address _trc20Token,
        address _omnibusWallet
    ) external onlyOwner {
        ITRC20 trc20Token = ITRC20(_trc20Token);
        uint256 balance = trc20Token.balanceOf(address(this));
        if (balance == 0) return;
        trc20Token.safeTransferChecked(_omnibusWallet, balance);
        emit SweepedToken(_trc20Token, _omnibusWallet, balance);
    }

    // Function to withdraw TRC20 Standard tokens to a hot wallet
    function sweepTRC20(
        address _trc20Token,
        address _omnibusWallet
    ) external onlyOwner {
        ITRC20 trc20Token = ITRC20(_trc20Token);
        uint256 balance = trc20Token.balanceOf(address(this));
        if (balance == 0) return;
        trc20Token.safeTransfer(_omnibusWallet, balance);
        emit SweepedToken(_trc20Token, _omnibusWallet, balance);
    }

    // Function to withdraw TRX (native TRON currency) from the wallet to a specified address
    function sweepTRX(
        uint256 amount,
        address payable _address
    ) external onlyOwner nonReentrant {
        _address.sendValue(amount); //transfer is depreciated so using sendValue from OZ instead
        emit SweepedTRX(_address, amount);
    }
}
