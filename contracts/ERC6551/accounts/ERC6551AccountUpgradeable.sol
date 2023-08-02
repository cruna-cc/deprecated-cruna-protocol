// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";
import {ERC6551Account} from "./ERC6551Account.sol";

/**
 * @title ERC6551AccountUpgradeable
 * @notice A lightweight smart contract wallet implementation that can be used by ERC6551AccountProxy
 */
contract ERC6551AccountUpgradeable is ERC6551Account {
  address public deployer;

  /**
   * @dev Storage slot with the address of the current implementation.
   * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
   * validated in the constructor.
   */
  bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

  constructor() {
    deployer = msg.sender;
  }

  /**
   * @dev Upgrades the implementation.
   */
  function upgrade(address implementation_) public {
    require(deployer == msg.sender, "Caller not the deployer");
    //    require(owner() == msg.sender, "Caller is not owner");
    require(implementation_ != address(0), "Invalid implementation address");
    ++_state;
    StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = implementation_;
  }
}
