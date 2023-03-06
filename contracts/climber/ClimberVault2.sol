//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./ClimberVault.sol";
import "solady/src/utils/SafeTransferLib.sol";

contract ClimberVault2 is OwnableUpgradeable, UUPSUpgradeable {
    uint256 public constant WITHDRAWAL_LIMIT = 1 ether;
    uint256 public constant WAITING_PERIOD = 15 days;
    uint256 private _lastWithdrawalTimestamp;
    address private _sweeper;

    // Allows trusted sweeper account to retrieve any tokens
    function sweepFunds(address token) external onlyOwner {
        SafeTransferLib.safeTransfer(
            token,
            msg.sender,
            IERC20(token).balanceOf(address(this))
        );
    }

    // By marking this internal function with `onlyOwner`, we only allow the owner account to authorize an upgrade
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
