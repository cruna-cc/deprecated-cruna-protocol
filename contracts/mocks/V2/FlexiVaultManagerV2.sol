// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Author: Francesco Sullo <francesco@sullo.co>

import {FlexiVaultManager, IERC165, IERC6551Registry, IERC6551Account, IERC6551Executable, IERC6551AccountExecutable} from "../../vaults/FlexiVaultManager.sol";
import {TrusteeV2, ITrustee, Trustee} from "./TrusteeV2.sol";

//import {console} from "hardhat/console.sol";

contract FlexiVaultManagerV2 is FlexiVaultManager {
  error PreviousTrusteeAlreadySet();

  // solhint-disable-next-line
  constructor(address owningToken, address tokenUtils) FlexiVaultManager(owningToken, tokenUtils) {}

  /**
   * @dev {See IVersioned-version}
   */
  function version() external pure virtual override returns (string memory) {
    return "2.0.0";
  }

  function setPreviousTrustees(address[] calldata previous_) external override onlyOwner {
    if (previousTrusteesCount != 0) revert PreviousTrusteeAlreadySet();
    for (uint i = 0; i < previous_.length; i++) {
      Trustee trustee_ = Trustee(previous_[i]);
      if (trustee_.isTrustee() != ITrustee.isTrustee.selector) revert InvalidTrustee();
      previousTrustees[i] = trustee_;
    }
    previousTrusteesCount = previous_.length;
  }

  /**
   * @dev {See IFlexiVaultManager.sol-init}
   */
  function init(
    address registry,
    address payable boundAccount_,
    address payable boundAccountUpgradeable_
  ) external virtual override onlyOwner {
    if (_initiated) revert AlreadyInitiated();
    if (!IERC165(registry).supportsInterface(type(IERC6551Registry).interfaceId)) revert InvalidRegistry();
    if (
      !IERC165(boundAccount_).supportsInterface(type(IERC6551Account).interfaceId) ||
      !IERC165(boundAccount_).supportsInterface(type(IERC6551Executable).interfaceId)
    ) revert InvalidAccount();
    if (
      !IERC165(boundAccountUpgradeable_).supportsInterface(type(IERC6551Account).interfaceId) ||
      !IERC165(boundAccountUpgradeable_).supportsInterface(type(IERC6551Executable).interfaceId)
    ) revert InvalidAccount();
    _registry = IERC6551Registry(registry);
    boundAccount = IERC6551AccountExecutable(boundAccount_);
    boundAccountUpgradeable = IERC6551AccountExecutable(boundAccountUpgradeable_);
    trustee = new TrusteeV2();
    _initiated = true;
  }
}
