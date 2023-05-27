// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Author: Francesco Sullo <francesco@sullo.co>

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "../nft-owned/NFTOwned.sol";
import "./IProtectedERC721Extended.sol";

//import "hardhat/console.sol";

abstract contract ProtectedERC721 is IProtectedERC721Extended, ERC721 {
  using ECDSA for bytes32;
  // tokenId => isApprovable
  mapping(uint256 => bool) private _notApprovable;

  // the address of a second wallet required to validate the transfer of a token
  // the user can set up to 2 protectors
  // owner >> protector >> approved
  mapping(address => Protector[]) private _protectors;

  // the address of the owner given the second wallet required to start the transfer
  mapping(address => address) private _ownersByProtector;

  mapping(address => Status) private _lockedProtectorsFor;

  // The operators that can manage a specific tokenId.
  // Operators are not restricted to follow an owner, as protectors do.
  // The idea is that for any tokenId there can be just a few operators
  // so we do not risk to go out of gas when checking them.
  mapping(uint => address[]) private _operators;

  // the tokens currently being transferred when a second wallet is set
  //  mapping(uint256 => ControlledTransfer) private _controlledTransfers;
  mapping(uint256 => bool) private _approvedTransfers;
  mapping(bytes32 => bool) private _usedSignatures;

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

  function signedByProtector(uint tokenId, bytes32 hash, bytes memory signature) public view override returns (bool) {
    address signer = hash.recover(signature);
    address owner_ = ownerOf(tokenId);
    (, Status status) = _findProtector(owner_, signer);
    return status > Status.UNSET;
  }

  function hashTransferRequest(uint256 tokenId, address to, uint256 timestamp) public view override returns (bytes32) {
    return keccak256(abi.encodePacked("\x19\x01", block.chainid, tokenId, to, timestamp));
  }

  function protectedTransfer(
    uint tokenId,
    address to,
    uint256 timestamp,
    bytes calldata signature
  ) external override onlyTokenOwner(tokenId) {
    if (timestamp > block.timestamp || timestamp < block.timestamp - 1 days) revert TimestampInvalidOrExpired();
    bytes32 hash = hashTransferRequest(tokenId, to, timestamp);
    if (!signedByProtector(tokenId, hash, signature)) revert WrongDataOrNotSignedByProtector();
    if (_usedSignatures[keccak256(signature)]) revert SignatureAlreadyUsed();
    setSignatureAsUsed(keccak256(signature));
    _approvedTransfers[tokenId] = true;
    _transfer(_msgSender(), to, tokenId);
    delete _approvedTransfers[tokenId];
  }

  function isSignatureUsed(bytes32 hashedSignature) external view override returns (bool) {
    return _usedSignatures[hashedSignature];
  }

  function setSignatureAsUsed(bytes32 hashedSignature) public override {
    _usedSignatures[hashedSignature] = true;
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

  // operators

  function getOperatorForIndexIfExists(uint tokenId, address operator) public view override returns (bool, uint) {
    for (uint i = 0; i < _operators[tokenId].length; i++) {
      if (_operators[tokenId][i] == operator) return (true, i);
    }
    return (false, 0);
  }

  function isOperatorFor(uint tokenId, address operator) public view override returns (bool) {
    for (uint i = 0; i < _operators[tokenId].length; i++) {
      if (_operators[tokenId][i] == operator) return true;
    }
    return false;
  }

  function setOperatorFor(uint tokenId, address operator, bool active) external onlyTokenOwner(tokenId) {
    if (operator == address(0)) revert InvalidAddress();
    (bool exists, uint i) = getOperatorForIndexIfExists(tokenId, operator);
    if (active) {
      if (exists) revert OperatorAlreadyActive();
      else _operators[tokenId].push(operator);
    } else {
      if (!exists) revert OperatorNotActive();
      else if (i != _operators[tokenId].length - 1) {
        _operators[tokenId][i] = _operators[tokenId][_operators[tokenId].length - 1];
      }
      _operators[tokenId].pop();
    }
    emit OperatorUpdated(tokenId, operator, active);
  }

  function isOwnerOrOperator(uint tokenId, address ownerOrOperator) external view override returns (bool) {
    return ownerOf(tokenId) == ownerOrOperator || isOperatorFor(tokenId, ownerOrOperator);
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId,
    uint256 batchSize
  ) internal virtual override(ERC721) {
    if (!isTransferable(tokenId, from, to)) revert TransferNotPermitted();
    delete _operators[tokenId];
    super._beforeTokenTransfer(from, to, tokenId, batchSize);
  }

  function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721) returns (bool) {
    return interfaceId == type(IProtectedERC721).interfaceId || super.supportsInterface(interfaceId);
  }

  // IERC6454

  function isTransferable(uint256 tokenId, address from, address to) public view override returns (bool) {
    // In general it is not transferable and burning is not allowed
    // so we can just verify the to
    if (to == address(0)) return false;
    // if from zero, it is minting
    else if (from == address(0)) return true;
    else {
      _requireMinted(tokenId);
      return _countActiveProtectors(ownerOf(tokenId)) == 0 || _approvedTransfers[tokenId];
    }
  }

  uint256[50] private __gap;
}
