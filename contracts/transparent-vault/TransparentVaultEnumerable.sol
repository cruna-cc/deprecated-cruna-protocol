// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;
pragma experimental ABIEncoderV2;

// Author: Francesco Sullo <francesco@sullo.co>

import "./TransparentVault.sol";
import "../protected-nft/IProtectedERC721.sol";
import "../storage/EnumerableStorage.sol";

//import "hardhat/console.sol";

// This version is enumerable, i.e., it is possible for another contract to know the balance
// of any owningTokenId. Unfortunately, there is a cost needed to reach this goal, and the average
// gas cost of a deposit is higher than the non-enumerable version.
// Specifically, to deposit an ERC721 with the not-enumerable version you spend
// an average of 120K gas, while with the enumerable version you spend 220K gas.
// Despite the higher gas cost, the enumerable version is more flexible and allows
// composability with other contracts. On cheap chains, like Polygon, it would make
// sense to deploy the enumerable version, while on expensive chains, like Ethereum,
// it would make sense to deploy the non-enumerable version. In any case, it is a
// choice that the project implementing the vault can make.

contract TransparentVaultEnumerable is TransparentVault, EnumerableStorage {
  // solhint-disable-next-line
  function __TransparentVaultEnumerable_init(address owningToken) internal onlyInitializing {
    __NFTOwned_init(owningToken);
    if (_owningToken.supportsInterface(type(IProtectedERC721).interfaceId)) {
      _owningTokenIsProtected = true;
    }
    __ReentrancyGuard_init();
  }

  function _addAmountToDeposit(uint owningTokenId, address asset, uint id, uint amount) internal override {
    _save(owningTokenId, asset, id, int256(amount));
  }

  function _checkIfCanTransfer(
    uint256 owningTokenId,
    address asset,
    uint256 id,
    uint256 amount
  ) internal view override returns (bytes32) {
    if (amount == 0) revert InvalidAmount();
    bytes32 key = keccak256(abi.encodePacked(owningTokenId, asset, id));
    if (getAmount(owningTokenId, asset, id) < amount) revert InsufficientBalance();
    return key;
  }

  function _transferAsset(
    uint256 owningTokenId,
    uint256 recipientOwningTokenId,
    address asset,
    uint256 id,
    uint256 amount
  ) internal override {
    if (recipientOwningTokenId > 0) {
      if (!_owningTokenExists(recipientOwningTokenId)) revert InvalidRecipient();
      _save(recipientOwningTokenId, asset, id, int256(amount));
    } // else the tokens is trashed
    _save(owningTokenId, asset, id, -int256(amount));
    emit DepositTransfer(recipientOwningTokenId, asset, id, amount, owningTokenId);
  }

  function _withdrawAsset(
    uint256 owningTokenId,
    address beneficiary,
    address asset,
    uint256 id,
    uint256 amount
  ) internal override {
    _save(owningTokenId, asset, id, -int256(amount));
    emit Withdrawal(owningTokenId, beneficiary, asset, id, amount);
    _transferToken(address(this), beneficiary, asset, id, amount);
  }

  // External services who need to see what a transparent vault contains can call
  // the Cruna Web API to get the list of assets owned by a owningToken. Then, they can call
  // this view to validate the results.
  function amountOf(
    uint256 owningTokenId,
    address[] memory asset,
    uint256[] memory id
  ) external view override returns (uint256[] memory) {
    uint256[] memory amounts = new uint256[](asset.length);
    for (uint256 i = 0; i < asset.length; i++) {
      amounts[i] = getAmount(owningTokenId, asset[i], id[i]);
    }
    return amounts;
  }

  uint256[50] private __gap;
}
