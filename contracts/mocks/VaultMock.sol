// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

import {CrunaFlexiVault} from "../vaults/CrunaFlexiVault.sol";

// reference implementation of a Cruna Vault
contract VaultMock is CrunaFlexiVault {
  constructor(address actorsManager, address signatureValidator) CrunaFlexiVault(actorsManager, signatureValidator) {}

  function safeMint0(address to) public onlyOwner {
    _mintNow(to);
  }
}
