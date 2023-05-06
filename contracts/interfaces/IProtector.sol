// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Author: Francesco Sullo <francesco@sullo.co>

import "@cruna/toolkit/badge/IERC6982.sol";
import "@cruna/toolkit/badge/IERC721DefaultApprovable.sol";
import "./IProtectorBase.sol";

interface IProtector is IERC6982, IERC721DefaultApprovable, IProtectorBase {
  // status
  // true: transfer initializer is being set
  // false: transfer initializer is being removed
  event InitiatorStarted(address indexed owner, address indexed initiator, bool status);
  // status
  // true: transfer initializer is set
  // false: transfer initializer is removed
  event InitiatorUpdated(address indexed owner, address indexed initiator, bool status);
  //
  event TransferStarted(address indexed initiator, uint256 indexed tokenId, address indexed to);
  event TransferExpired(uint256 tokenId);

  error NotTheTokenOwner();
  error NotApprovable();
  error NotApprovableForAll();
  error NotTheContractDeployer();
  error InvalidAddress();
  error TokenDoesNotExist();
  error SenderDoesNotOwnAnyToken();
  error InitiatorNotFound();
  error TokenAlreadyBeingTransferred();
  error AssociatedToAnotherOwner();
  error InitiatorAlreadySet();
  error InitiatorAlreadySetByYou();
  error NotInitiator();
  error NotOwnByRelatedOwner();
  error TransferNotPermitted();
  error TokenIdTooBig();
  error PendingInitiatorNotFound();
  error UnsetAlreadyStarted();
  error UnsetNotStarted();
  error NotTheInitiator();

  struct ControlledTransfer {
    address initiator;
    uint32 expiresAt;
    // ^ 24 bytes
    address to;
    bool approved;
    // ^ 21 bytes
  }

  enum Status {
    UNSET,
    PENDING,
    ACTIVE,
    REMOVABLE
  }

  enum Scope {
    EVERYTHING,
    PROTECTOR,
    ASSET_TRANSFER,
    WITHDRAWAL
  }

  struct Initiator {
    address initiator;
    // the transfer initializer has to approve its role
    Status status;
    // TODO
    //    Scope scope;
  }

  function exists(uint256 tokenId) external view returns (bool);

  function makeApprovable(uint256 tokenId, bool status) external;

  function initiatorFor(address owner_) external view returns (address);

  function hasInitiator(address owner_) external view returns (bool);

  function isInitiatorFor(address wallet) external view returns (address);

  function setInitiator(address initiator) external;

  function confirmInitiator(address owner_) external;

  function refuseInitiator(address owner_) external;

  function unsetInitiator() external;

  function confirmUnsetInitiator(address owner_) external;

  function hasInitiator(uint256 tokenId) external view returns (bool);

  function startTransfer(
    uint256 tokenId,
    address to,
    uint256 validFor
  ) external;

  function completeTransfer(uint256 tokenId) external;

  function batchMintProtected(uint256[] memory tokenIds, address subordinate) external;

  function mintProtected(uint256 tokenId, address subordinate) external;
}
