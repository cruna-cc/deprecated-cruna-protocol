// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

import {FlexiVault} from "../vaults/FlexiVault.sol";

// reference implementation of a Cruna Vault
contract FlexiVaultMock is FlexiVault {
  constructor(
    address tokenUtils,
    address actorsManager,
    address signatureValidator
  ) FlexiVault(tokenUtils, actorsManager, signatureValidator) {}

  function safeMint0(address to) public onlyOwner {
    _mintNow(to);
  }
}
