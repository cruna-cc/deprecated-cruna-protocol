// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

import {IFlexiVaultManager} from "../vaults/IFlexiVaultManager.sol";

// reference implementation of a Cruna Vault
interface IFlexiVault {
  function initVault(address flexiVaultManager) external;

  function setSignatureAsUsed(bytes calldata signature) external;

  function updateTokenURI(string memory uri) external;

  function freezeTokenURI() external;

  function contractURI() external view returns (string memory);
}
