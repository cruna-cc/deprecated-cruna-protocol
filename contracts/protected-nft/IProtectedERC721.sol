// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Author: Francesco Sullo <francesco@sullo.co>

import "../soulbound/IERC6982.sol";
import "../soulbound/IERC721DefaultApprovable.sol";

// erc165 interfaceId 0x8dca4bea

interface IProtectedERC721 is IERC6982, IERC721DefaultApprovable {
  // status
  // true: transfer initializer is being set
  // false: transfer initializer is being removed
  event ProtectorStarted(address indexed owner, address indexed protector, bool status);
  // status
  // true: transfer initializer is set
  // false: transfer initializer is removed
  event ProtectorUpdated(address indexed owner, address indexed protector, bool status);
  //
  event TransferStarted(address indexed protector, uint256 indexed tokenId, address indexed to);
  event TransferExpired(uint256 tokenId);

  error NotTheTokenOwner();
  error NotApprovable();
  error NotApprovableForAll();
  error NotTheContractDeployer();
  error InvalidAddress();
  error TokenDoesNotExist();
  error SenderDoesNotOwnAnyToken();
  error ProtectorNotFound();
  error TokenAlreadyBeingTransferred();
  error AssociatedToAnotherOwner();
  error ProtectorAlreadySet();
  error ProtectorAlreadySetByYou();
  error NotProtector();
  error NotOwnByRelatedOwner();
  error TransferNotPermitted();
  error TokenIdTooBig();
  error PendingProtectorNotFound();
  error UnsetAlreadyStarted();
  error UnsetNotStarted();
  error NotTheProtector();

  struct ControlledTransfer {
    address protector;
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

  struct Protector {
    address protector;
    // the transfer initializer has to approve its role
    Status status;
    // UNUSED
    // Scope scope;
  }

  function makeApprovable(uint256 tokenId, bool status) external;

  function protectorFor(address owner_) external view returns (address);

  function hasProtector(address owner_) external view returns (bool);

  function isProtectorFor(address wallet) external view returns (address);

  function setProtector(address protector) external;

  function confirmProtector(address owner_) external;

  function refuseProtector(address owner_) external;

  function unsetProtector() external;

  function confirmUnsetProtector(address owner_) external;

  function hasProtector(uint256 tokenId) external view returns (bool);

  function startTransfer(uint256 tokenId, address to, uint256 validFor) external;

  function completeTransfer(uint256 tokenId) external;
}
