// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";
import {Account} from "./Account.sol";
import {AccountGuardian} from "./AccountGuardian.sol";

/**
 * @title AccountUpgradeable.sol
 * @notice A lightweight smart contract wallet implementation that can be used by AccountProxy.sol
 */
contract AccountUpgradeable is Account {
  address public guardian;

  /**
   * @dev Storage slot with the address of the current implementation.
   * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
   * validated in the constructor.
   */
  bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

  constructor(address guardian_) {
    require(AccountGuardian(guardian_).isAccountGuardian(), "Not a guardian");
    guardian = guardian_;
  }

  /**
   * @dev Upgrades the implementation.
   */
  function upgrade(address implementation_) public {
    require(msg.sender == owner(), "Caller not the owner");
    require(implementation_ != address(0), "Invalid implementation address");
    require(AccountGuardian(guardian).isTrustedImplementation(implementation_), "Untrusted implementation");
    ++_state;
    StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = implementation_;
  }
}
