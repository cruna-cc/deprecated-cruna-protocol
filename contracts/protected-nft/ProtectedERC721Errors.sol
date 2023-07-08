// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Author: Francesco Sullo <francesco@sullo.co>

import {IActors} from "./IActors.sol";

// erc165 interfaceId 0x8dca4bea
interface ProtectedERC721Errors {
  error NotTheTokenOwner();
  error NotApprovable();
  error NotApprovableForAll();
  error NotTheContractDeployer();
  error TokenDoesNotExist();
  error SenderDoesNotOwnAnyToken();
  error ProtectorNotFound();
  error TokenAlreadyBeingTransferred();
  error AssociatedToAnotherOwner();
  error ProtectorAlreadySet();
  error ProtectorAlreadySetByYou();
  error NotAProtector();
  error NotOwnByRelatedOwner();
  error NotPermittedWhenProtectorsAreActive();
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
  error NotAFlexiVault();
  error VaultAlreadyAdded();
  error InvalidTokenUtils();
  error QuorumCannotBeZero();
  error QuorumCannotBeGreaterThanBeneficiaries();
  error BeneficiaryNotConfigured();
  error NotExpiredYet();
  error BeneficiaryAlreadyRequested();
  error InconsistentRecipient();
  error NotABeneficiary();
  error RequestAlreadyApproved();
  error NotTheRecipient();
  error Unauthorized();
  error NotTransferable();
}
