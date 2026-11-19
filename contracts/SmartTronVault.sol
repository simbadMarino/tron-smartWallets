//SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/*
TRON  TRON Energy Pool Contract (TEPC) requirements:

Goal: 
1. Create a SC in such a way that developer can build a TRON Resources delegation automation platform, flash rentals trough external TRON EOAs should be enabled as well

Usual Workflow:


Background:


Identified Use Cases:

1. TRON Energy Pool 

Contract Requirements:
2. Only ADMIN can edit ADMIN roles --> Done
4. Only ADMIN must be able to withdraw TRX -> Done
5. Optionally Add a white list function for users to avoid smart contract abuse beyond the owner's platform. -> Pending
6. Implement Error handling, feedback and logging for all functions --> Pending
7. Create Smart contract test cases --> Pending
8. Only white-listed users can delegate resources --> DONE
9. White-listed users have a configurable max resource they can access per day (consider block number per day here) --> Pending

TO-DO:

*/
import {AccessControl} from "@openzeppelin/tron-contracts/access/AccessControl.sol";

contract TronEnergyPool is AccessControl {
    // Defining our contract roles:
    bytes32 public constant DELEGATOR_ROLE = keccak256("DELEGATOR_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    uint256 public energyPerTRX;
    uint256 public netPerTRX;

    event TransferExecuted(
        address indexed from,
        address indexed to,
        uint256 amount
    );
    error InvalidResourceType(uint8 resourceType);
    error InvalidAmountOrPriceNotInitialized();
    error UnDelegateCallFailed();

    event AddressAdminGranted(address indexed account);
    event AddressDelegatorGranted(address indexed account);

    event BalanceFreezedV2(uint256, uint256);
    event ResourcePerTRXEvent(uint256);
    event BalanceUnfreezedV2(uint256, uint256);
    event AllUnFreezeV2Canceled();
    event DestroyContract();
    event ExpireUnfreezeWithdrew(uint256);
    event ResourceDelegated(
        address indexed caller,
        address indexed delegateTo,
        uint256 amount,
        uint8 resourceType,
        uint256 timestamp
    );
    event QuickDelegation(
        address indexed caller,
        address indexed delegateTo,
        uint256 amount,
        uint8 resourceType,
        uint256 timestamp
    );
    event ResourceUnDelegated(
        address indexed caller,
        address indexed unDelegateTo,
        uint256 amount,
        uint8 resourceType,
        uint256 timestamp
    );
    event withdrawnBalance(address indexed recipient, uint256 amount);

    constructor() {
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function makeUserAdmin(address account) external onlyRole(ADMIN_ROLE) {
        _grantRole(ADMIN_ROLE, account);
        emit AddressAdminGranted(account);
    }

    function revokeAdmin(address account) external onlyRole(ADMIN_ROLE) {
        require(account != msg.sender, "Admins cannot remove themselves"); // Prevent self-revoke
        _revokeRole(ADMIN_ROLE, account);
    }

    function makeUserDelegator(address account) external onlyRole(ADMIN_ROLE) {
        _grantRole(DELEGATOR_ROLE, account);
        emit AddressDelegatorGranted(account);
    }

    function revokeDelegator(address account) external onlyRole(ADMIN_ROLE) {
        _revokeRole(DELEGATOR_ROLE, account);
    }

    /**
     * @notice Query the amount of resources share of a specific resourceType delegated by from to address
     * @param to delegated resource to address
     * @param from resource owner
     * @param resourceType Energy: 1 , Bandwidth: 0
     */
    function getResourceV2(
        address to,
        address from,
        uint8 resourceType
    ) public view returns (uint256) {
        if (resourceType != 0 && resourceType != 1)
            revert InvalidResourceType(resourceType);
        return to.resourceV2(from, resourceType);
    }

    /**
     * @notice Delegate Resource in Resource units
     * @param amountInRes Amount of resource to be delegated
     * @param resourceType Energy: 1  Bandwidth: 0
     * @param delegateTo to address
     */
    function delegateResource(
        uint256 amountInRes,
        uint8 resourceType, //Energy: 1 , Bandwidth: 0
        address payable delegateTo
    ) public onlyRole(DELEGATOR_ROLE) {
        if (amountInRes == 0 && energyPerTRX == 0 && netPerTRX == 0)
            revert InvalidAmountOrPriceNotInitialized();
        if (resourceType > 1) revert InvalidResourceType(resourceType); //If Wrong input by user revert
        uint256 amountInTRX;

        if (resourceType == 1) {
            amountInTRX = (amountInRes * 1_000_000_000_000) / energyPerTRX;
        } else if (resourceType == 0) {
            amountInTRX = (amountInRes * 1_000_000_000_000) / netPerTRX;
        }

        delegateTo.delegateResource(amountInTRX, resourceType);
        emit ResourceDelegated(
            msg.sender,
            delegateTo,
            amountInRes,
            resourceType,
            block.timestamp
        );
    }

    /**
     * @notice Undelegate Resource in Resource units
     * @param amountInRes Amount of resource to be delegated
     * @param resourceType Energy: 1  Bandwidth: 0
     * @param unDelegateTo to address
     */
    function unDelegateResource(
        uint256 amountInRes,
        uint8 resourceType, //Energy: 1 , Bandwidth: 0
        address payable unDelegateTo
    ) public onlyRole(DELEGATOR_ROLE) {
        if (amountInRes == 0 && energyPerTRX == 0 && netPerTRX == 0)
            revert InvalidAmountOrPriceNotInitialized();
        if (resourceType > 1) revert InvalidResourceType(resourceType); //If Wrong input by user revert
        uint256 amountInTRX;

        if (resourceType == 1) {
            amountInTRX = (amountInRes * 1_000_000_000_000) / energyPerTRX;
        } else if (resourceType == 0) {
            amountInTRX = (amountInRes * 1_000_000_000_000) / netPerTRX;
        }
        unDelegateTo.unDelegateResource(amountInTRX, resourceType);
        emit ResourceUnDelegated(
            msg.sender,
            unDelegateTo,
            amountInRes,
            resourceType,
            block.timestamp
        );
    }

    function quickEnergyDelegation(
        address payable delegateTo
    ) external onlyRole(DELEGATOR_ROLE) {
        delegateResource(5000000, 1, delegateTo);
        emit QuickDelegation(
            msg.sender,
            delegateTo,
            5_000_000,
            1,
            block.timestamp
        );
    }

    function quickBandwidthDelegation(
        address payable delegateTo
    ) external onlyRole(DELEGATOR_ROLE) {
        delegateResource(30000, 0, delegateTo);
        emit QuickDelegation(
            msg.sender,
            delegateTo,
            30_000,
            0,
            block.timestamp
        );
    }

    // Stake TRX to obtain Voting power and Resources (Either Energy: 1 or Bandwidth:0)
    function freezeBalance(
        uint256 amount,
        uint8 resourceType //Energy: 1 , Bandwidth: 0
    ) external onlyRole(ADMIN_ROLE) {
        if (resourceType != 0 && resourceType != 1)
            revert InvalidResourceType(resourceType);
        freezebalancev2(amount, resourceType);
        emit BalanceFreezedV2(amount, resourceType);
    }

    // unstake TRX
    function unfreezeBalance(
        uint256 amount,
        uint8 resourceType
    ) external onlyRole(ADMIN_ROLE) {
        if (resourceType != 0 && resourceType != 1)
            revert InvalidResourceType(resourceType);
        unfreezebalancev2(amount, resourceType);
        emit BalanceUnfreezedV2(amount, resourceType);
    }

    // Function to withdraw TRX (native TRON currency) from the wallet to a specified address
    function withdrawBalance(
        uint256 amount, // Amount of TRX to withdraw
        address payable _address // Recipient's address
    ) external onlyRole(ADMIN_ROLE) {
        // Only the owner can call this function
        _address.transfer(amount);
        emit withdrawnBalance(_address, amount);
    }

    /**
     * @notice  Get Chain parameters , remove to reduce deployment cost for now
     */
    /*
    function getChainParameters() public view returns (uint256, uint256, uint256, uint256, uint256) {
        return (
            chain.totalNetLimit,
            chain.totalNetWeight,
            chain.totalEnergyCurrentLimit,
            chain.totalEnergyWeight,
            chain.unfreezeDelayDays
        );
    }*/

    /**
     * @notice  Calculate the Energy per TRX ratio considering current Network conditions
     */
    function calculateEnergyPerTRX() public returns (uint256) {
        energyPerTRX =
            (chain.totalEnergyCurrentLimit * 1_000_000) /
            chain.totalEnergyWeight;
        emit ResourcePerTRXEvent(energyPerTRX);
        return (energyPerTRX);
    }

    /**
     * @notice  Calculate the Bandwidth per TRX ratio considering current Network conditions
     */
    function calculateNetPerTRX() public returns (uint256) {
        netPerTRX = (chain.totalNetLimit * 1_000_000) / chain.totalNetWeight;
        emit ResourcePerTRXEvent(netPerTRX);
        return (netPerTRX);
    }

    /**
     * @notice cancel all pending unstaking requests. Before calling selfdestruct(address) to destroy the contract, should cancel all pending unstaking requests, otherwise, the contract cannot be destroyed.
     */
    function cancelUnfreeze() public onlyRole(ADMIN_ROLE) {
        cancelallunfreezev2();
        emit AllUnFreezeV2Canceled();
    }

    /**
     * @notice  cancel all pending unstaking requests and destroy the contract
     */
    function destroyContract(
        address payable target
    ) external onlyRole(ADMIN_ROLE) {
        cancelallunfreezev2();
        emit DestroyContract();
        selfdestruct(target);
    }

    /**
     * @notice withdraw unfrozen TRX, the user can call this API to withdraw funds to account after executing unfreezeBalanceV2 transaction and waiting N days, N is a network parameter.
     */
    function withdrawExpireUnfreeze() external onlyRole(ADMIN_ROLE) {
        uint256 amount = withdrawexpireunfreeze();
        emit ExpireUnfreezeWithdrew(amount);
    }

    /**
     * @notice Query the usage of a specific resourceType of resources for address
     * @param to Address to be analyzed
     * @param resourceType Energy: 1 , Bandwidth: 0
     */
    /*function getResourceUsage(
        address to,
        uint8 resourceType //Energy: 1 , Bandwidth: 0
    ) public view returns (uint256, uint256) {
        (uint256 used, uint256 restoreTime) = to.resourceUsage(resourceType);
        return (used, restoreTime);
    }*/

    /**
     * @notice Query the total available resource share of a specific resourceType for address
     * @param to Address to be analyzed
     * @param resourceType Energy: 1 , Bandwidth: 0
     */
    /*function getTotalResource(
        address to,
        uint8 resourceType //Energy: 1 , Bandwidth: 0
    ) public view returns (uint256) {
        if (resourceType != 0 && resourceType != 1) revert InvalidResourceType(resourceType);
        return to.totalResource(resourceType);
    }*/

    /**
     * @notice Query delegated resources share of a specific resourceType for address
     * @param to Address to be analyzed
     * @param resourceType Energy: 1 , Bandwidth: 0
     */
    /*function getTotalDelegatedResource(address to, uint8 resourceType) public view returns (uint256) {
        if (resourceType != 1 && resourceType != 0) revert InvalidResourceType(resourceType);
        return to.totalDelegatedResource(resourceType);
    }*/

    /**
     * @notice Query the acquired resource share of a specific resourceType for address
     * @param to Address to be analyzed
     * @param resourceType Energy: 1 , Bandwidth: 0
     * @return The amount of acquired resource share, the unit is sun
     */
    /*function getTotalAcquiredResource(address to, uint8 resourceType) public view returns (uint256) {
        return to.totalAcquiredResource(resourceType);
    }*/

    /**
     * @notice Vote witness in srList array and every witness will get correspond TP in tpList array
     * @param srList SR List
     * @param tpList Number of votes for super representatives in srList
     */
    function voteWitness(
        address[] calldata srList,
        uint[] calldata tpList
    ) external onlyRole(ADMIN_ROLE) {
        vote(srList, tpList);
    }

    /**
     * @notice  Withdraw all allowance and reward to contract balance
     * @return Actually withdrawn balance of allowance and reward. unit is sun.
     */
    function withdrawReward() external onlyRole(ADMIN_ROLE) returns (uint256) {
        return withdrawreward();
    }

    /**
     * @notice  Query all allowance and reward of contract account
     * @return Sum of allowance and reward of contradct account
     */
    function queryRewardBalance() external view returns (uint256) {
        return rewardBalance();
    }
}
