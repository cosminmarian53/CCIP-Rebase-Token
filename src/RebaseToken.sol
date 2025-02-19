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
pragma solidity ^0.8.24;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
/*
 *@title RebaseToken
 *@author Cosmin Marian
 *@notice This is a cross-chain rebase token that incentivizes users to put into a vault and gain interest
 *@notice This interest rate can only be decreased
 *@notice Each user will have their own interest rate that is the global interest rate at the deposit time
 */
contract RebaseToken is ERC20 {
    // # ------------------------------------------------------------------
    // #                              ERRORS
    // # ------------------------------------------------------------------
    error RebaseToken__InterestRateCanOnlyDecrease(
        uint256 newInterestRate,
        uint256 oldInterestRate
    );
    // # ------------------------------------------------------------------
    // #                         STATE VARIABLES
    // # ------------------------------------------------------------------
    uint256 private s_interestRate = 5e10;
    uint256 private constant PRECISION_FACTOR = 1e18;
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;
    // # ------------------------------------------------------------------
    // #                              EVENTS
    // # ------------------------------------------------------------------
    event InterestRateChanged(uint256 newInterestRate);
    // # ------------------------------------------------------------------
    // #                           CONSTRUCTOR
    // # ------------------------------------------------------------------
    constructor() ERC20("Rebase Token", "RBT") {
        // do something
    }
    // # ------------------------------------------------------------------
    // #                        EXTERNAL FUNCTIONS
    // # ------------------------------------------------------------------
    /*
     *@notice This function will set the interest rate
     *@param _interestRate The new interest rate
     *@dev This function will revert if the new interest rate is less than the current interest rate
     *@notice This function will emit an event with the new interest rate
     *@notice The interest rate can only be decreased
     */
    function setInterestRate(uint256 _interestRate) public {
        if (_interestRate < s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(
                _interestRate,
                s_interestRate
            );
        }
        s_interestRate = _interestRate;
        emit InterestRateChanged(_interestRate);
    }
    /*
     *@notice This function will mint the token to the user
     *@param _to The user address
     *@param _amount The amount to mint
     *@dev This function will mint the accrued interest to the user
     *@dev This function will set the user interest rate to the global interest rate
     */
    function mint(address _to, uint256 _amount) external {
        _mintAccruredInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }
    /*
     *@notice This function will get the interest rate
     *@param _user The user address
     *@return The interest rate
     */
    function getUserInterestRate(
        address _user
    ) external view returns (uint256) {
        return s_userInterestRate[_user];
    }
    function balanceOf(address account) public view override returns (uint256) {
        return
            super.balanceOf(account) *
            _calculateUserAccumulatedInterestSinceLastUpdate(account)/PRECISION_FACTOR;
    }

    // # ------------------------------------------------------------------
    // #                        INTERNAL FUNCTIONS
    // # ------------------------------------------------------------------
    /*
     *@notice This function will calculate the user accumulated interest since the last update
     *@param _user The user address
     *@return The interest rate that has been accumulated since the last update
     */
    function _calculateUserAccumulatedInterestSinceLastUpdate(
        address _user
    ) internal view returns (uint256 linearInterest) {
        uint256 timeElapsed = block.timestamp -
            s_userLastUpdatedTimestamp[_user];
        linearInterest = (PRECISION_FACTOR + (s_userInterestRate[_user] * timeElapsed));
    }

    function _mintAccruredInterest(address _user) internal {
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
        uint256 interestRate = s_userInterestRate[_user];
        uint256 balance = balanceOf(_user);
        uint256 interest = (balance * interestRate) / 1e18;
        _mint(_user, interest);
    }
}
