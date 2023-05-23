// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

import "../../vault/TransparentVaultPool.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract CoolProjectTransparentVault is TransparentVaultPool, OwnableUpgradeable, UUPSUpgradeable {
  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(address protector) public initializer {
    __Ownable_init();
    __UUPSUpgradeable_init();
    __TransparentVault_init(protector);
  }

  // required by UUPSUpgradeable
  function _authorizeUpgrade(address) internal override onlyOwner {}
}
