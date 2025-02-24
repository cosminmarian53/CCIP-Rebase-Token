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
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
/**
 *@title RebaseToken
 *@author Cosmin Marian
 *@notice This is a cross-chain rebase token that incentivizes users to put into a vault and gain interest
 *@notice This interest rate can only be decreased
 *@notice Each user will have their own interest rate that is the global interest rate at the deposit time
 */
contract RebaseToken is ERC20, Ownable, AccessControl {
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
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;
    // # ------------------------------------------------------------------
    // #                              EVENTS
    // # ------------------------------------------------------------------
    event InterestRateChanged(uint256 newInterestRate);
    // # ------------------------------------------------------------------
    // #                           CONSTRUCTOR
    // # ------------------------------------------------------------------
    constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender) {
        // do something
    }

    // # ------------------------------------------------------------------
    // #                        EXTERNAL FUNCTIONS
    // # ------------------------------------------------------------------
    function grantMintAndBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }
    /**
     *@notice This function will set the interest rate
     *@param _interestRate The new interest rate
     *@dev This function will revert if the new interest rate is less than the current interest rate
     *@notice This function will emit an event with the new interest rate
     *@notice The interest rate can only be decreased
     */
    function setInterestRate(uint256 _interestRate) external onlyOwner {
        if (_interestRate < s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(
                _interestRate,
                s_interestRate
            );
        }
        s_interestRate = _interestRate;
        emit InterestRateChanged(_interestRate);
    }
    /**
     *@notice This function will mint the token to the user
     *@param _to The user address
     *@param _amount The amount to mint
     *@dev This function will mint the accrued interest to the user
     *@dev This function will set the user interest rate to the global interest rate
     */
    function mint(address _to, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }
    /**
     *@notice This function will burn the token from the user when they withdraw from the vault
     *@param _from The user address
     *@param _amount The amount to burn
     *@dev This function will mint the accrued interest to the user
     */
    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    /**
     *@notice This function will get the interest rate
     *@param _user The user address
     *@return The interest rate
     */
    function getUserInterestRate(
        address _user
    ) external view returns (uint256) {
        return s_userInterestRate[_user];
    }

    /**
     * @notice This function will get the interest rate that is currently set for the contract
     * @return The interest rate
     */
    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return
            (super.balanceOf(account) *
                _calculateUserAccumulatedInterestSinceLastUpdate(account)) /
            PRECISION_FACTOR;
    }

    /**
     * @notice  Get the principle balance of the user. This is the number of tokens that have currently been minted to the user
     * @notice  not including the interest that has been accrued since the last time the user interacted with the protocol
     * @param   account  : the user to get the principle balance of
     * @return  uint256  : the principle balance of the user
     */
    function principleBalanceOf(
        address account
    ) external view returns (uint256) {
        return super.balanceOf(account);
    }
    /**
     * @notice  Transfer tokens from sender to recipient
     * @param   _recipient : the user to transfer to
     * @param   _amount  : the amount to transfer
     * @return  bool : true if transfer is successful
     */
    function transfer(
        address _recipient,
        uint256 _amount
    ) public override returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }

        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }
        return super.transfer(_recipient, _amount);
    }

    /**
     * @notice  Transfer tokens from sender to recipient
     * @param   _sender  : the user to transfer from
     * @param   _recipient  : the user to transfer to
     * @param   _amount  : the amount to transfer
     * @return  bool  : true if transfer is successful
     */
    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) public override returns (bool) {
        _mintAccruedInterest(_sender);
        _mintAccruedInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }

        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[_sender];
        }
        return super.transferFrom(_sender, _recipient, _amount);
    }

    // # ------------------------------------------------------------------
    // #                        INTERNAL FUNCTIONS
    // # ------------------------------------------------------------------

    /**
     *@notice This function will calculate the user accumulated interest since the last update
     *@param _user The user address
     *@return linearInterest : The interest rate that has been accumulated since the last update
     */
    function _calculateUserAccumulatedInterestSinceLastUpdate(
        address _user
    ) internal view returns (uint256 linearInterest) {
        uint256 timeElapsed = block.timestamp -
            s_userLastUpdatedTimestamp[_user];
        linearInterest = (PRECISION_FACTOR +
            (s_userInterestRate[_user] * timeElapsed));
    }

    /**
     *@notice This function will mint the accrued interest to the user since the last time they interacted with the protocol
     *@param _user The user address
     *@dev This function will calculate the user's current balance + interest
     *@dev This function will calculate the number of tokens that need to be minted to the user
     *@dev This function will set the user's last updated timestamp to the current block timestamp
     */

    function _mintAccruedInterest(address _user) internal {
        // (1) find the current balance of rebase tokens that have been minted to the user
        uint256 previousPrincipleBalance = super.balanceOf(_user);
        // (2) calculate their current balance + interest
        uint256 currentBalance = balanceOf(_user);
        // (3) calculate the number of tokens that need to be minted to the user
        uint256 balanceIncrease = currentBalance - previousPrincipleBalance;
        // set the user's last updated timestamp to the current block timestamp
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
        _mint(_user, balanceIncrease);
    }
}
