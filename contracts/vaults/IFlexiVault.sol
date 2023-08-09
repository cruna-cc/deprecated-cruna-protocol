// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

import {IFlexiVaultManager} from "../vaults/IFlexiVaultManager.sol";

// reference implementation of a Cruna Vault
interface IFlexiVault {
  function initVault(address flexiVaultManager) external;

  function setSignatureAsUsed(bytes calldata signature) external;

  function setFactory(address factory) external;

  function safeMint(address to) external;

  function mintFromTrustee(uint tokenId) external;

  function ejectAccount(uint256 tokenId, uint256 timestamp, uint256 validFor, bytes calldata signature) external;

  function injectEjectedAccount(uint256 tokenId) external;

  function activateAccount(uint256 tokenId, bool useUpgradeableAccount) external;

  // deposits

  function depositAssets(
    uint256 tokenId,
    IFlexiVaultManager.TokenType[] memory tokenTypes,
    address[] memory assets,
    uint256[] memory ids,
    uint256[] memory amounts
  ) external payable;

  function withdrawAssets(
    uint256 tokenId,
    IFlexiVaultManager.TokenType[] memory tokenTypes,
    address[] memory assets,
    uint256[] memory ids,
    uint256[] memory amounts,
    address[] memory recipients,
    uint256 timestamp,
    uint256 validFor,
    bytes calldata signature
  ) external;
}
