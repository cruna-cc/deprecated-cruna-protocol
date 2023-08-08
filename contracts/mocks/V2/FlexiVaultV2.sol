// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

import {FlexiVault} from "../../vaults/FlexiVault.sol";
import {Trustee} from "../../ERC6551/Trustee.sol";

//import "hardhat/console.sol";

// reference implementation of a Cruna Vault
contract FlexiVaultV2 is FlexiVault {
  error AlreadyMinted();
  error NotFromTrustee();

  mapping(uint => Trustee) public previousTrustees;
  uint public previousTrusteesCount;

  constructor(address tokenUtils, address actorsManager) FlexiVault(tokenUtils, actorsManager) {}

  function safeMint0(address to) public onlyOwner {
    _mintNow(to);
  }

  function version() external pure override returns (string memory) {
    return "2.0.0";
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return "https://meta.cruna.cc/flexy-vault/v2/";
  }

  function contractURI() public view virtual override returns (string memory) {
    return "https://meta.cruna.cc/flexy-vault/v2/info";
  }

  function initVault(address flexiVaultManager) public virtual override onlyOwner {
    super.initVault(flexiVaultManager);
    previousTrusteesCount = vaultManager.previousTrusteesCount();
    for (uint i = 0; i < previousTrusteesCount; i++) {
      previousTrustees[i] = vaultManager.previousTrustees(i);
    }
  }

  function mintFromTrustee(uint tokenId) external virtual override {
    if (_exists(tokenId)) revert AlreadyMinted();
    for (uint i = 0; i < previousTrusteesCount; i++) {
      if (previousTrustees[i].firstTokenId() <= tokenId && tokenId <= previousTrustees[i].lastTokenId()) {
        if (previousTrustees[i].ownerOf(tokenId) != _msgSender()) revert NotTheTokenOwner();
        _safeMint(_msgSender(), tokenId);
        return;
      }
    }
    revert NotFromTrustee();
  }

  function reInjectEjectedAccount(uint256 tokenId) external virtual override onlyTokenOwner(tokenId) {
    if (trustee.firstTokenId() <= tokenId && tokenId <= trustee.lastTokenId()) {
      if (trustee.ownerOf(tokenId) == address(vaultManager)) revert NotAPreviouslyEjectedAccount();
      trustee.transferFrom(_msgSender(), address(vaultManager), tokenId);
      vaultManager.reInjectEjectedAccount(tokenId);
    } else {
      for (uint i = 0; i < previousTrusteesCount; i++) {
        if (previousTrustees[i].firstTokenId() <= tokenId && tokenId <= previousTrustees[i].lastTokenId()) {
          if (previousTrustees[i].ownerOf(tokenId) == address(vaultManager)) revert NotAPreviouslyEjectedAccount();
          previousTrustees[i].transferFrom(_msgSender(), address(vaultManager), tokenId);
          vaultManager.reInjectEjectedAccount(tokenId, previousTrustees[i].boundAccount(tokenId));
          return;
        }
      }
    }
  }

  function fixDirectlyInjectedAccount(uint256 tokenId) external virtual override onlyTokenOwner(tokenId) {
    if (!_exists(tokenId)) revert TokenIdDoesNotExist();
    vaultManager.fixDirectlyInjectedAccount(tokenId);
  }
}
