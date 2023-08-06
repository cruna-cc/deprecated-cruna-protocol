// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

import {FlexiVault} from "../vaults/FlexiVault.sol";

// reference implementation of a Cruna Vault
contract FlexiVaultMock is FlexiVault {
  constructor(
    string memory baseUri_,
    address tokenUtils,
    address actorsManager
  ) FlexiVault(baseUri_, tokenUtils, actorsManager) {}

  function safeMint0(address to) public onlyOwner {
    _mintNow(to);
  }
}
