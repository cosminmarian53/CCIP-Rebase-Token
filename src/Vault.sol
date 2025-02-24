// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {IRebaseToken} from "./interfaces/IRebaseToken.sol";
// # ------------------------------------------------------------------
// #                              ERRORS
// # ------------------------------------------------------------------
error Vault__RedeemFailed();
contract Vault {
    // we need to pass the token address to the constructor
    // create a deposit function that mints tokens to the user equal to the amount of ETH the user has sent
    // create a redeem function that burns tokens from the user and sends to the user  ETH
    // # ------------------------------------------------------------------
    // #                         STATE VARIABLES
    // # ------------------------------------------------------------------
    IRebaseToken private immutable i_rebaseToken;

    // # ------------------------------------------------------------------
    // #                              EVENTS
    // # ------------------------------------------------------------------
    event Deposited(address indexed user, uint256 amount);
    event Redeemed(address indexed user, uint256 amount);
    // # ------------------------------------------------------------------
    // #                           CONSTRUCTOR
    // # ------------------------------------------------------------------
    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }
    // # ------------------------------------------------------------------
    // #                        EXTERNAL FUNCTIONS
    // # ------------------------------------------------------------------
    function getRebaseTokenAddress() external view returns (address) {
        return address(i_rebaseToken);
    }
    /**
     * @notice Deposit ETH into the vault to receive tokens
     * @dev The amount of tokens minted to the user is equal to the amount of ETH sent
    */
    function deposit() external payable {
        // 1. Use the amount of ETH sent to calculate the amount of tokens to
        // mint to the user
        i_rebaseToken.mint(msg.sender, msg.value);
        emit Deposited(msg.sender, msg.value);
    }
    /**
     * @notice Redeem tokens for ETH
     * @param _amount The amount of tokens to redeem
    */
    function redeem(uint256 _amount) external {
        // 1. Burn the amount of tokens from the user
        // 2. Send the user the amount of ETH equal to the amount of tokens burned
        i_rebaseToken.burn(msg.sender, _amount);
        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert Vault__RedeemFailed();
        }
        emit Redeemed(msg.sender, _amount);
    }
}
