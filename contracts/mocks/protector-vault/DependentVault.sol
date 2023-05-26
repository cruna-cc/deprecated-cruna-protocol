// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../../vaults/TransparentVault.sol";

contract DependentVault is TransparentVault, Ownable {
  constructor(address owningToken) TransparentVault(owningToken) {}

  function _canInit() internal override onlyOwner {}
}
