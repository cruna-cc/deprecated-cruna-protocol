// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// from https://github.com/erc6551/reference

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Upgrade.sol";
import "@openzeppelin/contracts/proxy/Proxy.sol";

contract ERC6551AccountProxy is Proxy, ERC1967Upgrade {
  // solhint-disable-next-line
  address immutable defaultImplementation;

  constructor(address _defaultImplementation) {
    defaultImplementation = _defaultImplementation;
  }

  function _implementation() internal view virtual override returns (address) {
    address implementation = ERC1967Upgrade._getImplementation();

    if (implementation == address(0)) return defaultImplementation;

    return implementation;
  }

  function isERC6551Account() external pure returns (bool) {
    return true;
  }
}
