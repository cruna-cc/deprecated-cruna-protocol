// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Author: Francesco Sullo <francesco@sullo.co>

import "./IFlexiVault.sol";

interface IFlexiVaultExtended is IFlexiVault {
  event BoundAccountEjected(uint256 indexed owningTokenId);
  event EjectedBoundAccountReInjected(uint256 indexed owningTokenId);

  error ForbiddenWhenOwningTokenApprovedForSale();
  error InconsistentLengths();
  error InsufficientBalance();
  error InvalidAmount();
  error InvalidAsset();
  error NotAllowedWhenProtector();
  error NotTheProtector();
  error NotTheOwningTokenOwner();
  error TransferFailed();
  error InvalidRegistry();
  error InvalidAccount();
  error AccountAlreadyActive();
  error NoETH();
  error NotActivated();
  error AccountHasBeenEjected();
  error NotAPreviouslyEjectedAccount();
  error AccountAlreadyEjected();
  error ETHDepositFailed();
  error AlreadyInitiated();
  error NotTheOwningTokenOwnerOrOperatorFor();
  error TimestampInvalidOrExpired();
  error WrongDataOrNotSignedByProtector();
  error SignatureAlreadyUsed();
  error OwningTokenNotProtected();
  error VaultHasBeenUpgraded();
  error InvalidTokenUtils();

  enum TokenType {
    ERC20,
    ERC721,
    ERC1155
  }
}
