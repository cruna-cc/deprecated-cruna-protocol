// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../../dominant-subordinate/ERC721SubordinateUpgradeable.sol";

contract MySubordinateUpgradeable is ERC721SubordinateUpgradeable, UUPSUpgradeable {
  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(address myTokenEnumerableUpgradeable) public initializer {
    __ERC721Subordinate_init("My Subordinate", "mSUBu", myTokenEnumerableUpgradeable);
    __UUPSUpgradeable_init();
  }

  function _authorizeUpgrade(address) internal virtual override {}

  function getInterfaceId() public pure returns (bytes4) {
    return type(IERC721Subordinate).interfaceId;
  }
}
