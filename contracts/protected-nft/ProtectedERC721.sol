// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Author: Francesco Sullo <francesco@sullo.co>

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "../nft-owned/NFTOwned.sol";
import "./IProtectedERC721Extended.sol";

//import "hardhat/console.sol";

abstract contract ProtectedERC721 is IProtectedERC721Extended, ERC721 {
  // tokenId => isApprovable
  mapping(uint256 => bool) private _notApprovable;

  // the address of a second wallet required to start the transfer of a token
  // the user can set up to 2 protectors
  // owner >> protector >> approved
  mapping(address => Protector[]) private _protectors;

  // the address of the owner given the second wallet required to start the transfer
  mapping(address => address) private _ownersByProtector;

  mapping(address => Status) private _lockedProtectorsFor;

  // the tokens currently being transferred when a second wallet is set
  mapping(uint256 => ControlledTransfer) private _controlledTransfers;

  modifier onlyProtectorFor(address owner_) {
    (uint i, Status status) = _findProtector(owner_, _msgSender());
    if (status < Status.ACTIVE) revert NotAProtector();
    _;
  }

  modifier onlyProtectorForTokenId(uint tokenId_) {
    address owner_ = ownerOf(tokenId_);
    (uint i, Status status) = _findProtector(owner_, _msgSender());
    if (status < Status.ACTIVE) revert NotAProtector();
    _;
  }

  modifier onlyTokenOwner(uint256 tokenId) {
    if (ownerOf(tokenId) != _msgSender()) revert NotTheTokenOwner();
    _;
  }

  modifier onlyTokensOwner() {
    if (balanceOf(_msgSender()) == 0) revert NotATokensOwner();
    _;
  }

  constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {}

  function _countActiveProtectors(address tokensOwner_) internal view returns (uint) {
    uint activeProtectorCount = 0;
    for (uint i = 0; i < _protectors[tokensOwner_].length; i++) {
      if (_protectors[tokensOwner_][i].status > Status.PENDING) {
        activeProtectorCount++;
      }
    }
    return activeProtectorCount;
  }

  function protectorsFor(address tokensOwner_) external view override returns (address[] memory) {
    address[] memory activeProtectors = new address[](_countActiveProtectors(tokensOwner_));
    uint activeIndex = 0;
    for (uint i = 0; i < _protectors[tokensOwner_].length; i++) {
      if (_protectors[tokensOwner_][i].status > Status.PENDING) {
        activeProtectors[activeIndex] = _protectors[tokensOwner_][i].protector;
        activeIndex++;
      }
    }
    return activeProtectors;
  }

  function isProtectorFor(address tokensOwner_, address protector_) external view override returns (bool) {
    for (uint i = 0; i < _protectors[tokensOwner_].length; i++) {
      if (_protectors[tokensOwner_][i].protector == protector_ && _protectors[tokensOwner_][i].status > Status.PENDING) {
        return true;
      }
    }
    return false;
  }

  function _getProtectorStatus(address tokensOwner_, address protector_) internal view returns (Status) {
    for (uint i = 0; i < _protectors[tokensOwner_].length; i++) {
      if (_protectors[tokensOwner_][i].protector == protector_) {
        return _protectors[tokensOwner_][i].status;
      }
    }
    return Status.UNSET;
  }

  function proposeProtector(address protector_) external onlyTokensOwner {
    if (protector_ == address(0)) revert InvalidAddress();
    // in this contract we limit to max 2 protectors
    if (_protectors[_msgSender()].length == 2) revert TooManyProtectors();
    if (_ownersByProtector[protector_] != address(0)) {
      if (_ownersByProtector[protector_] == _msgSender()) revert ProtectorAlreadySetByYou();
      else revert AssociatedToAnotherOwner();
    }
    Status status = _getProtectorStatus(_msgSender(), protector_);
    if (status != Status.UNSET) revert ProtectorAlreadySet();
    _protectors[_msgSender()].push(Protector(protector_, Status.PENDING));
    emit ProtectorProposed(_msgSender(), protector_);
  }

  function _findProtector(address tokensOwner_, address protector_) private view returns (uint, Status) {
    for (uint i = 0; i < _protectors[tokensOwner_].length; i++) {
      if (_protectors[tokensOwner_][i].protector == protector_) {
        return (i, _protectors[tokensOwner_][i].status);
      }
    }
    return (0, Status.UNSET);
  }

  function _validatePendingProtector(address tokensOwner_, address protector_) private view returns (uint) {
    (uint i, Status status) = _findProtector(tokensOwner_, protector_);
    if (status == Status.PENDING) {
      return i;
    } else {
      revert PendingProtectorNotFound();
    }
  }

  function _removeProtector(address tokensOwner_, uint i) private {
    if (i < _protectors[tokensOwner_].length - 1) {
      emit ProtectorUpdated(tokensOwner_, _protectors[tokensOwner_][i].protector, false);
      _protectors[tokensOwner_][i] = _protectors[tokensOwner_][_protectors[tokensOwner_].length - 1];
    }
    _protectors[tokensOwner_].pop();
  }

  function acceptProposal(address tokensOwner_, bool accepted_) external {
    uint i = _validatePendingProtector(tokensOwner_, _msgSender());
    if (_ownersByProtector[_msgSender()] != address(0)) {
      // the transfer initializer has been associated to another owner in between the
      // set and the confirmation
      revert AssociatedToAnotherOwner();
    }
    if (accepted_) {
      _protectors[tokensOwner_][i].status = Status.ACTIVE;
      _ownersByProtector[_msgSender()] = tokensOwner_;
    } else {
      _removeProtector(tokensOwner_, i);
    }
    emit ProtectorUpdated(tokensOwner_, _msgSender(), accepted_);
  }

  function resignAsProtectorFor(address tokensOwner_) external {
    (uint i, Status status) = _findProtector(tokensOwner_, _msgSender());
    if (status == Status.UNSET) {
      revert NotAProtector();
    } else if (status == Status.REMOVABLE) {
      revert ResignationAlreadySubmitted();
    } else if (status == Status.ACTIVE) {
      _protectors[_msgSender()][i].status = Status.REMOVABLE;
      emit ProtectorResigned(_msgSender(), _msgSender());
    } else {
      // it obtains similar results like not accepting a proposal
      _removeProtector(tokensOwner_, i);
    }
  }

  function acceptResignation(address protector_) external onlyTokensOwner {
    (uint i, Status status) = _findProtector(_msgSender(), protector_);
    if (status == Status.REMOVABLE) {
      _removeProtector(_msgSender(), i);
      if (_countActiveProtectors(_msgSender()) == 0) {
        //        emit Locked(_msgSender());
      }
    } else {
      revert ResignationNotSubmitted();
    }
  }

  function initiateTransfer(uint256 tokenId, address to, uint256 validFor) external {
    address owner_ = ownerOf(tokenId);
    (, Status status) = _findProtector(owner_, _msgSender());
    if (status < Status.ACTIVE) revert NotAProtector();
    if (to == address(0) || to == owner_) revert InvalidAddress();
    if (validFor == 0) revert InvalidDuration();
    if (_controlledTransfers[tokenId].protector != address(0)) revert TransferAlreadyInitiated();
    uint expiresAt = block.timestamp + validFor;
    _controlledTransfers[tokenId] = ControlledTransfer({
      protector: _msgSender(),
      to: to,
      expiresAt: uint32(expiresAt),
      approved: false
    });
    emit TransferStartedBy(_msgSender(), tokenId, to, expiresAt);
  }

  function approveTransfer(uint256 tokenId, bool approved_) public onlyTokenOwner(tokenId) returns (bool) {
    ControlledTransfer storage transfer_ = _controlledTransfers[tokenId];
    if (transfer_.protector == address(0)) revert TransferNotInitiated();
    if (transfer_.expiresAt < block.timestamp) {
      delete _controlledTransfers[tokenId];
      return false;
    }
    if (approved_) {
      _controlledTransfers[tokenId].approved = true;
      emit TransferApproved(tokenId, _controlledTransfers[tokenId].to, approved_);
      return true;
    }
    delete _controlledTransfers[tokenId];
    return false;
  }

  function approveAndExecuteTransfer(uint256 tokenId, bool approved_) external onlyTokenOwner(tokenId) {
    if (approveTransfer(tokenId, approved_)) {
      _transfer(_msgSender(), _controlledTransfers[tokenId].to, tokenId);
    }
  }

  function lockProtectors() external onlyTokensOwner {
    if (_countActiveProtectors(_msgSender()) == 0) revert NoActiveProtectors();
    if (_lockedProtectorsFor[_msgSender()] == Status.UNSET) {
      _lockedProtectorsFor[_msgSender()] = Status.ACTIVE;
      emit ProtectorsLocked(_msgSender(), true);
    } else {
      // it can be active or set for removal
      revert ProtectorsAlreadyLocked();
    }
  }

  function unlockProtectorsFor(address tokensOwner_) external onlyProtectorFor(tokensOwner_) {
    if (_lockedProtectorsFor[tokensOwner_] == Status.UNSET) revert ProtectorsNotLocked();
    if (_lockedProtectorsFor[tokensOwner_] != Status.REMOVABLE) revert ProtectorsUnlockAlreadyStarted();
    // else is Status.ACTIVE
    _lockedProtectorsFor[tokensOwner_] = Status.REMOVABLE;
  }

  function approveUnlockProtectors(bool approved) external onlyTokensOwner {
    if (_lockedProtectorsFor[_msgSender()] != Status.REMOVABLE) revert ProtectorsUnlockNotStarted();
    if (approved) {
      delete _lockedProtectorsFor[_msgSender()];
      emit ProtectorsLocked(_msgSender(), false);
    } else {
      // reverts the change from REMOVABLE to ACTIVE
      _lockedProtectorsFor[_msgSender()] = Status.ACTIVE;
    }
  }

  // The following functions are overrides required by Solidity.
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId,
    uint256 batchSize
  ) internal virtual override(ERC721) {
    // Skips the minting
    if (!isTransferable(tokenId, from, to)) revert TransferNotPermitted();
    // if an controlled transfer was set, it will be deleted
    delete _controlledTransfers[tokenId];
    super._beforeTokenTransfer(from, to, tokenId, batchSize);
  }

  function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721) returns (bool) {
    return interfaceId == type(IProtectedERC721).interfaceId || super.supportsInterface(interfaceId);
  }

  // IERC6454

  function isTransferable(uint256 tokenId, address from, address) public view override returns (bool) {
    return (from == address(0) || // is minting
      _countActiveProtectors(ownerOf(tokenId)) == 0 || // there are no active protectors
      _controlledTransfers[tokenId].approved); // there are protectors but the transfer was approved
  }

  function _safeMint(address to, uint256 tokenId, bytes memory data) internal virtual override {
    // to optimize gas management inside the protected, we encode
    // the tokenId on 24 bits. Max tokenID: 16777215
    if (tokenId > type(uint24).max) revert TokenIdTooBig();
    super._safeMint(to, tokenId, data);
  }

  //

  uint256[50] private __gap;
}
