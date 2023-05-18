// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

import "../../vault/AirdroppableTransparentSafeBox.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract CoolProjectAirdroppableTransparentVault is AirdroppableTransparentSafeBox, OwnableUpgradeable, UUPSUpgradeable {
  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(address protector, address registry, address payable proxy) public initializer {
    __Ownable_init();
    __UUPSUpgradeable_init();
    __AirdroppableTransparentSafeBox_init(protector, registry, proxy);
  }

  // required by UUPSUpgradeable
  function _authorizeUpgrade(address) internal override onlyOwner {}
}
