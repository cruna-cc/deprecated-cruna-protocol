// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

import {CrunaFlexiVault} from "../../vaults/CrunaFlexiVault.sol";
import {CrunaWallet} from "../../vaults/CrunaWallet.sol";

//import "hardhat/console.sol";

// reference implementation of a Cruna Vault
contract FlexiVaultV2 is CrunaFlexiVault {
  error AlreadyMinted();
  error NotFromCrunaWallet();

  mapping(uint => CrunaWallet) public previousCrunaWallets;
  uint public previousCrunaWalletsCount;

  constructor(address actorsManager, address signatureValidator) CrunaFlexiVault(actorsManager, signatureValidator) {}

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
    previousCrunaWalletsCount = vaultManager.previousCrunaWalletsCount();
    for (uint i = 0; i < previousCrunaWalletsCount; i++) {
      previousCrunaWallets[i] = vaultManager.previousCrunaWallets(i);
    }
  }

  function mintFromCrunaWallet(uint tokenId) external virtual override {
    if (_exists(tokenId)) revert AlreadyMinted();
    for (uint i = 0; i < previousCrunaWalletsCount; i++) {
      if (previousCrunaWallets[i].firstTokenId() <= tokenId && tokenId <= previousCrunaWallets[i].lastTokenId()) {
        if (previousCrunaWallets[i].ownerOf(tokenId) != _msgSender()) revert NotTheTokenOwner();
        _safeMint(_msgSender(), tokenId);
        return;
      }
    }
    revert NotFromCrunaWallet();
  }

  function injectEjectedAccount(uint256 tokenId) external virtual override onlyTokenOwner(tokenId) nonReentrant {
    if (!_exists(tokenId)) revert TokenIdDoesNotExist();
    bool done;
    // it reverts if called before initiating the vault, or with non-existing token
    if (wallet.firstTokenId() <= tokenId && tokenId <= wallet.lastTokenId()) {
      if (wallet.ownerOf(tokenId) != address(vaultManager)) {
        wallet.transferFrom(_msgSender(), address(vaultManager), tokenId);
        done = true;
      }
    } else {
      for (uint i = 0; i < previousCrunaWalletsCount; i++) {
        if (previousCrunaWallets[i].firstTokenId() <= tokenId && tokenId <= previousCrunaWallets[i].lastTokenId()) {
          if (previousCrunaWallets[i].ownerOf(tokenId) != address(vaultManager)) {
            previousCrunaWallets[i].transferFrom(_msgSender(), address(vaultManager), tokenId);
            done = true;
            break;
          }
        }
      }
    }
    if (done) {
      vaultManager.injectEjectedAccount(tokenId);
    } else {
      revert NotAPreviouslyEjectedAccount();
    }
  }
}
