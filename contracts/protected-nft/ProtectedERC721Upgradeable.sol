// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Author: Francesco Sullo <francesco@sullo.co>

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "../nft-owned/NFTOwned.sol";
import "./IProtectedERC721.sol";

// import "hardhat/console.sol";

abstract contract ProtectedERC721Upgradeable is IProtectedERC721, Initializable, ERC721Upgradeable {
  // tokenId => isApprovable
  mapping(uint256 => bool) private _notApprovable;

  // the address of a second wallet required to start the transfer of a token
  // owner >> protector >> approved
  mapping(address => Protector) private _protectors;

  // the address of the owner given the second wallet required to start the transfer
  mapping(address => address) private _ownersByProtector;

  // the tokens currently being transferred when a second wallet is set
  mapping(uint256 => ControlledTransfer) private _controlledTransfers;

  modifier notTheProtector(address owner_) {
    if (_protectors[owner_].protector != _msgSender()) revert NotProtector();
    _;
  }

  modifier onlyTokenOwner(uint256 tokenId) {
    if (ownerOf(tokenId) != _msgSender()) revert NotTheTokenOwner();
    _;
  }

  // solhint-disable-next-line
  function __ProtectedERC721_init(string memory name_, string memory symbol_) public onlyInitializing {
    __ERC721_init(name_, symbol_);
    emit DefaultApprovable(true);
    emit DefaultLocked(false);
  }

  // The following functions are overrides required by Solidity.
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId,
    uint256 batchSize
  ) internal virtual override(ERC721Upgradeable) {
    if (_protectors[from].status > Status.PENDING && !_controlledTransfers[tokenId].approved) {
      revert TransferNotPermitted();
    }
    super._beforeTokenTransfer(from, to, tokenId, batchSize);
  }

  function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Upgradeable) returns (bool) {
    return interfaceId == type(IProtectedERC721).interfaceId || super.supportsInterface(interfaceId);
  }

  function makeApprovable(uint256 tokenId, bool status) external virtual override onlyTokenOwner(tokenId) {
    // Notice that making it approvable is irrelevant if a transfer initializer is set
    // But the setting will makes sense if/when the transfer initializer is removed
    if (!status) {
      _notApprovable[tokenId] = true;
    } else if (_notApprovable[tokenId]) {
      delete _notApprovable[tokenId];
    }
    emit Approvable(tokenId, status);
  }

  function approvable(uint256 tokenId) public view virtual override returns (bool) {
    if (!_exists(tokenId)) revert TokenDoesNotExist();
    return !_notApprovable[tokenId] && !hasProtector(tokenId);
  }

  // IERC6982

  function locked(uint256 tokenId) public view virtual override returns (bool) {
    return approvable(tokenId);
  }

  function defaultLocked() public view virtual override returns (bool) {
    return false;
  }

  // overrides approval

  function approve(address to, uint256 tokenId) public virtual override(ERC721Upgradeable) {
    if (!approvable(tokenId)) revert NotApprovable();
    super.approve(to, tokenId);
  }

  function getApproved(uint256 tokenId) public view virtual override(ERC721Upgradeable) returns (address) {
    // a token may have been approved before it was made not approvable
    // so we need a double check
    if (!approvable(tokenId)) {
      return address(0);
    }
    return super.getApproved(tokenId);
  }

  function setApprovalForAll(address, bool) public virtual override(ERC721Upgradeable) {
    revert NotApprovableForAll();
  }

  function isApprovedForAll(address, address) public view virtual override(ERC721Upgradeable) returns (bool) {
    return false;
  }

  function _safeMint(address to, uint256 tokenId, bytes memory data) internal virtual override {
    // to optimize gas management inside the protected, we encode
    // the tokenId on 24 bits, which is large enough for an ID;
    // Max tokenID: 16777215
    if (tokenId > type(uint24).max) revert TokenIdTooBig();
    super._safeMint(to, tokenId, data);
  }

  // Manage transfer initializers

  function protectorFor(address owner_) external view override returns (address) {
    return _protectors[owner_].status > Status.ACTIVE ? _protectors[owner_].protector : address(0);
  }

  function hasProtector(address owner_) external view override returns (bool) {
    return _protectors[owner_].status > Status.PENDING;
  }

  function isProtectorFor(address wallet) external view override returns (address) {
    return _ownersByProtector[wallet];
  }

  function _removeExistingProtector(address owner_) private {
    delete _ownersByProtector[_protectors[owner_].protector];
    delete _protectors[owner_];
  }

  // Since the transfer initializer is by owner, we do not check if they
  // own any token. They may own one later in the future.
  // A wallet can be the transfer initializer for a single owner.
  // However, wallet A can be the TI for wallet B, while at same time,
  // wallet B can be the TI for wallet A.
  function setProtector(address protector) external virtual override {
    if (protector == address(0)) revert InvalidAddress();
    if (_ownersByProtector[protector] != address(0)) {
      if (_ownersByProtector[protector] == _msgSender()) revert ProtectorAlreadySetByYou();
      else revert AssociatedToAnotherOwner();
    }
    if (_protectors[_msgSender()].status != Status.UNSET) revert ProtectorAlreadySet();
    _protectors[_msgSender()] = Protector({protector: protector, status: Status.PENDING});
    emit ProtectorStarted(_msgSender(), protector, true);
  }

  function _validatePendingProtector(address owner_) private view {
    if (_protectors[owner_].protector != _msgSender()) revert NotTheProtector();
    if (_protectors[owner_].status != Status.PENDING) revert PendingProtectorNotFound();
  }

  // must be called by the transfer initializer
  function confirmProtector(address owner_) external virtual override {
    _validatePendingProtector(owner_);
    if (_ownersByProtector[_msgSender()] != address(0)) {
      // the transfer initializer has been associated to another owner in between the
      // set and the confirmation
      revert AssociatedToAnotherOwner();
    }
    _protectors[owner_].status = Status.ACTIVE;
    _ownersByProtector[_msgSender()] = owner_;
    emit ProtectorUpdated(owner_, _msgSender(), true);
  }

  function refuseProtector(address owner_) external virtual override {
    _validatePendingProtector(owner_);
    _removeExistingProtector(owner_);
    emit ProtectorUpdated(owner_, _msgSender(), false);
  }

  function unsetProtector() external virtual {
    if (_protectors[_msgSender()].status == Status.UNSET) revert ProtectorNotFound();
    if (_protectors[_msgSender()].status == Status.REMOVABLE) revert UnsetAlreadyStarted();
    if (_protectors[_msgSender()].status == Status.ACTIVE) {
      // require confirmation by the protector
      _protectors[_msgSender()].status = Status.REMOVABLE;
      emit ProtectorStarted(_msgSender(), _protectors[_msgSender()].protector, false);
    } else {
      // can be removed without confirmation
      emit ProtectorUpdated(_msgSender(), _protectors[_msgSender()].protector, false);
      _removeExistingProtector(_msgSender());
    }
  }

  function confirmUnsetProtector(address owner_) external virtual {
    if (_protectors[owner_].protector != _msgSender()) revert NotProtector();
    if (_protectors[owner_].status != Status.REMOVABLE) revert UnsetNotStarted();
    emit ProtectorUpdated(owner_, _msgSender(), false);
    _removeExistingProtector(owner_);
  }

  function hasProtector(uint256 tokenId) public view virtual override returns (bool) {
    address owner_ = ownerOf(tokenId);
    return _protectors[owner_].status > Status.PENDING;
  }

  // to reduce gas, we expect that the transfer is initiated by transfer initializer
  // and completed by the owner, which is the only one that can actually transfer
  // the token
  function startTransfer(uint256 tokenId, address to, uint256 validFor) external virtual override {
    address owner_ = _ownersByProtector[_msgSender()];
    if (owner_ == address(0)) revert NotProtector();
    if (ownerOf(tokenId) != owner_) revert NotOwnByRelatedOwner();
    if (_controlledTransfers[tokenId].protector != address(0) && _controlledTransfers[tokenId].expiresAt > block.timestamp)
      revert TokenAlreadyBeingTransferred();
    // else a previous transfer is expired or it was set by another transfer initializer
    _controlledTransfers[tokenId] = ControlledTransfer({
      protector: _msgSender(),
      to: to,
      expiresAt: uint32(block.timestamp + validFor),
      approved: false
    });
    emit TransferStarted(_msgSender(), tokenId, to);
  }

  // this must be called by the token owner
  function completeTransfer(uint256 tokenId) external virtual override {
    if (
      // the transfer initializer has changed since the transfer started
      _controlledTransfers[tokenId].protector != _protectors[_msgSender()].protector ||
      // the transfer is expired
      _controlledTransfers[tokenId].expiresAt < block.timestamp
    ) {
      delete _controlledTransfers[tokenId];
      emit TransferExpired(tokenId);
    } else {
      _controlledTransfers[tokenId].approved = true;
      _transfer(_msgSender(), _controlledTransfers[tokenId].to, tokenId);
      delete _controlledTransfers[tokenId];
      // No need to emit a specific event, since a Transfer event is emitted anyway
    }
  }

  function _afterTokenTransfer(
    address from,
    address to,
    uint256 tokenId,
    uint256 batchSize
  ) internal virtual override(ERC721Upgradeable) {
    super._afterTokenTransfer(from, to, tokenId, batchSize);
  }

  uint256[50] private __gap;
}
