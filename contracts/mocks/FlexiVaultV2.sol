// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Author: Francesco Sullo <francesco@sullo.co>

import {FlexiVault, IERC165, IERC6551Registry, IERC6551Account, TrusteeNFT, ITrusteeNFT} from "../vaults/FlexiVault.sol";

//import {console} from "hardhat/console.sol";

contract FlexiVaultV2 is FlexiVault {
  // solhint-disable-next-line
  constructor(address owningToken, address tokenUtils) FlexiVault(owningToken, tokenUtils) {}

  /**
   * @dev {See IVersioned-version}
   */
  function version() external pure override returns (string memory) {
    return "1.1.0";
  }

  /**
   * @dev {See IFlexiVault-init}
   */
  function init(
    address registry,
    address payable boundAccount_,
    address payable boundAccountUpgradeable_
  ) external override onlyOwner {
    if (_initiated) revert AlreadyInitiated();
    if (!IERC165(registry).supportsInterface(type(IERC6551Registry).interfaceId)) revert InvalidRegistry();
    if (!IERC165(boundAccount_).supportsInterface(type(IERC6551Account).interfaceId)) revert InvalidAccount();
    if (!IERC165(boundAccountUpgradeable_).supportsInterface(type(IERC6551Account).interfaceId)) revert InvalidAccount();
    _registry = IERC6551Registry(registry);
    boundAccount = IERC6551Account(boundAccount_);
    boundAccountUpgradeable = IERC6551Account(boundAccountUpgradeable_);
    _initiated = true;
  }

  function initTrustee(TrusteeNFT trustee_) external onlyOwner {
    if (!IERC165(trustee_).supportsInterface(type(ITrusteeNFT).interfaceId)) revert InvalidTrustee();
    trustee = new TrusteeNFT();
  }

  /**
   * @dev {See IFlexiVault-activateAccount}
   */
  function activateAccount(
    uint256 owningTokenId,
    bool useUpgradeableAccount
  ) external override onlyOwningTokenOwner(owningTokenId) {
    if (!trustee.isMinter(address(this))) {
      // If the contract is no more the minter, there is a new version of the
      // vault and new users must use the new version.
      revert VaultHasBeenUpgraded();
    }
    if (_accountAddresses[owningTokenId] != address(0)) revert AccountAlreadyActive();
    address account = address(useUpgradeableAccount ? boundAccountUpgradeable : boundAccount);
    address walletAddress = _registry.account(account, block.chainid, address(trustee), owningTokenId, _salt);
    trustee.mint(address(this), owningTokenId);
    _accountAddresses[owningTokenId] = walletAddress;
    _registry.createAccount(account, block.chainid, address(trustee), owningTokenId, _salt, "");
    emit BoundAccountActivated(owningTokenId, walletAddress);
  }
}
