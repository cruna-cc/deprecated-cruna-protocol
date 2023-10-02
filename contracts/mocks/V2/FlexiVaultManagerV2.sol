// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Author: Francesco Sullo <francesco@sullo.co>

import {FlexiVaultManager, IERC165, IERC6551Registry, IERC6551Account, IERC6551Executable, IERC6551AccountExecutable} from "../../vaults/FlexiVaultManager.sol";
import {CrunaWalletV2, ICrunaWallet, CrunaWallet} from "./CrunaWalletV2.sol";

//import {console} from "hardhat/console.sol";

contract FlexiVaultManagerV2 is FlexiVaultManager {
  error PreviousCrunaWalletAlreadySet();

  // solhint-disable-next-line
  constructor(address owningToken) FlexiVaultManager(owningToken) {}

  /**
   * @dev {See IVersioned-version}
   */
  function version() external pure virtual override returns (string memory) {
    return "2.0.0";
  }

  function setPreviousCrunaWallets(address[] calldata previous_) external override onlyOwner {
    if (previousCrunaWalletsCount != 0) revert PreviousCrunaWalletAlreadySet();
    for (uint i = 0; i < previous_.length; i++) {
      CrunaWallet wallet_ = CrunaWallet(previous_[i]);
      if (wallet_.isCrunaWallet() != ICrunaWallet.isCrunaWallet.selector) revert InvalidCrunaWallet();
      previousCrunaWallets[i] = wallet_;
    }
    previousCrunaWalletsCount = previous_.length;
  }

  /**
   * @dev {See IFlexiVaultManager.sol-init}
   */
  function init(address registry, address payable boundAccount_) external virtual override onlyOwner {
    if (_initiated) revert AlreadyInitiated();
    if (
      !IERC165(boundAccount_).supportsInterface(type(IERC6551Account).interfaceId) ||
      !IERC165(boundAccount_).supportsInterface(type(IERC6551Executable).interfaceId)
    ) revert InvalidAccount();
    _registry = IERC6551Registry(registry);
    boundAccount = IERC6551AccountExecutable(boundAccount_);
    wallet = new CrunaWalletV2();
    _initiated = true;
  }

  function injectEjectedAccount(uint256 owningTokenId) public virtual override onlyVault {
    _accountStatuses[owningTokenId] = AccountStatus.ACTIVE;
    if (_accountAddresses[owningTokenId] == address(0)) {
      // it is coming from a previous version
      for (uint i = 0; i < previousCrunaWalletsCount; i++) {
        if (previousCrunaWallets[i].firstTokenId() <= owningTokenId && owningTokenId <= previousCrunaWallets[i].lastTokenId()) {
          _accountAddresses[owningTokenId] = previousCrunaWallets[i].boundAccount(owningTokenId);
          break;
        }
      }
      if (_accountAddresses[owningTokenId] == address(0)) revert CrunaWalletNotFound();
    }
    emit EjectedBoundAccountReInjected(owningTokenId);
  }
}
