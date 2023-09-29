// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// from https://github.com/erc6551/reference

import {ERC6551AccountProxy} from "erc6551/examples/upgradeable/ERC6551AccountProxy.sol";

contract AccountProxy is ERC6551AccountProxy {
  constructor(address _defaultImplementation) ERC6551AccountProxy(_defaultImplementation) {}

  function isERC6551Account() external pure returns (bool) {
    return true;
  }
}
