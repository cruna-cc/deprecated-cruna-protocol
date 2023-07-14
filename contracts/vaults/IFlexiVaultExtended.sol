// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Author: Francesco Sullo <francesco@sullo.co>

import {IFlexiVault} from "./IFlexiVault.sol";

interface IFlexiVaultExtended is IFlexiVault {
  event BoundAccountEjected(uint256 indexed owningTokenId);
  event EjectedBoundAccountReInjected(uint256 indexed owningTokenId);

  /**
   * @dev Emitted when an operator is set/unset for a tokenId
   */
  event OperatorUpdated(uint256 indexed tokenId, address indexed operator, bool status);

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
  error TheAccountHasNeverBeenEjected();
  error TheAccountIsNotOwnedByTheFlexiVault();
  error OperatorAlreadyActive();
  error OperatorNotActive();
  error OnlyProtectedOwningToken();
  error NoZeroAddress();
}
