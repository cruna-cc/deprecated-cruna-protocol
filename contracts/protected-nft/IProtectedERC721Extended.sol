// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Author: Francesco Sullo <francesco@sullo.co>

import "./IERC6454.sol";
import "./IProtectedERC721.sol";

// erc165 interfaceId 0x8dca4bea

interface IProtectedERC721Extended is IProtectedERC721, IERC6454 {
  // status
  // true: transfer initializer is being set
  // false: transfer initializer is being removed
  event ProtectorUpdateStarted(address indexed owner, address indexed protector, bool status);
  // status
  // true: transfer initializer is set
  // false: transfer initializer is removed

  error NotTheTokenOwner();
  error NotApprovable();
  error NotApprovableForAll();
  error NotTheContractDeployer();
  error NoZeroAddress();
  error TokenDoesNotExist();
  error SenderDoesNotOwnAnyToken();
  error ProtectorNotFound();
  error TokenAlreadyBeingTransferred();
  error AssociatedToAnotherOwner();
  error ProtectorAlreadySet();
  error ProtectorAlreadySetByYou();
  error NotAProtector();
  error NotOwnByRelatedOwner();
  error TransferNotPermitted();
  error TokenIdTooBig();
  error PendingProtectorNotFound();
  error ResignationAlreadySubmitted();
  error UnsetNotStarted();
  error NotTheProtector();
  error NotATokensOwner();
  error ResignationNotSubmitted();
  error TooManyProtectors();
  error InvalidDuration();
  error NoActiveProtectors();
  error ProtectorsAlreadyLocked();
  error ProtectorsUnlockAlreadyStarted();
  error ProtectorsUnlockNotStarted();
  error ProtectorsNotLocked();
  error TimestampInvalidOrExpired();
  error WrongDataOrNotSignedByProtector();
  error SignatureAlreadyUsed();
  error OperatorAlreadyActive();
  error OperatorNotActive();
  error NotATransparentVault();
  error VaultAlreadyAdded();

  enum Status {
    UNSET,
    PENDING,
    ACTIVE,
    RESIGNED
  }

  struct Protector {
    address protector;
    Status status;
  }
}
