// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Author: Francesco Sullo <francesco@sullo.co>

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../nft-owned/NFTOwned.sol";
import "./IProtectedERC721.sol";
import "../utils/IVersioned.sol";
import "../vaults/IFlexiVault.sol";
import "../utils/ITokenUtils.sol";
import "./IERC6454.sol";
import "./Actors.sol";

import "hardhat/console.sol";

abstract contract ProtectedERC721 is IProtectedERC721, IERC6454, IVersioned, Actors, ERC721, ERC721Enumerable, Ownable {
  using ECDSA for bytes32;
  using Strings for uint256;

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

  ITokenUtils internal _tokenUtils;

  // the address of a second wallet required to validate the transfer of a token
  // the user can set up to 2 protectors
  // owner >> protector >> approved
  //  mapping(address => Protector[]) private _protectors;

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

  address[] private _vaults;

  struct BeneficiaryConf {
    uint256 quorum;
    uint256 proofOfLifeDurationInDays;
    uint256 lastProofOfLife;
  }

  struct BeneficiaryRequest {
    address recipient;
    uint256 startedAt;
    address[] approvers;
    // if there is a second thought about the recipient, the beneficiary can change it
    // after the request is expired if not approved in the meantime
  }

  mapping(address => BeneficiaryRequest) private _beneficiariesRequests;

  mapping(address => BeneficiaryConf) private _beneficiaryConfs;

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

  constructor(string memory name_, string memory symbol_, address tokenUtils) ERC721(name_, symbol_) {
    _tokenUtils = ITokenUtils(tokenUtils);
    if (_tokenUtils.isTokenUtils() != ITokenUtils.isTokenUtils.selector) revert InvalidTokenUtils();
  }

  function version() external view override returns (string memory) {
    return string(abi.encodePacked((_vaults.length + 1).toString(), ".0.0"));
  }

  function addVault(address vault) external onlyOwner {
    try IFlexiVault(vault).isFlexiVault() returns (bytes4 result) {
      if (result != IFlexiVault.isFlexiVault.selector) revert NotAFlexiVault();
    } catch {
      revert NotAFlexiVault();
    }
    for (uint i = 0; i < _vaults.length; i++) {
      if (_vaults[i] == vault) revert VaultAlreadyAdded();
    }
    _vaults.push(vault);
  }

  function getVault(uint index) external view returns (address) {
    return _vaults[index];
  }

  function _countActiveProtectors(address tokensOwner_) internal view returns (uint) {
    return _countActiveActorsByRole(tokensOwner_, Role.PROTECTOR);
  }

  function proposeProtector(address protector_) external onlyTokensOwner {
    if (protector_ == address(0)) revert NoZeroAddress();
    // in this contract we limit to max 2 protectors
    if (_actorLength(_msgSender(), Role.PROTECTOR) == 2) revert TooManyProtectors();
    if (_ownersByProtector[protector_] != address(0)) {
      if (_ownersByProtector[protector_] == _msgSender()) revert ProtectorAlreadySetByYou();
      else revert AssociatedToAnotherOwner();
    }
    Status status = _actorStatus(_msgSender(), protector_, Role.PROTECTOR);
    if (status != Status.UNSET) revert ProtectorAlreadySet();
    _addActor(_msgSender(), protector_, Role.PROTECTOR, Status.PENDING, Level.NONE);
    emit ProtectorProposed(_msgSender(), protector_);
  }

  function _findProtector(address tokensOwner_, address protector_) private view returns (uint, Status) {
    (uint i, Actor storage actor) = _getActor(tokensOwner_, protector_, Role.PROTECTOR);
    return (i, actor.status);
  }

  function _validatePendingProtector(address tokensOwner_, address protector_) private view returns (uint) {
    (uint i, Status status) = _findProtector(tokensOwner_, protector_);
    if (status == Status.PENDING) {
      return i;
    } else {
      revert PendingProtectorNotFound();
    }
  }

  function isProtectorFor(address tokensOwner_, address protector_) external view returns (bool) {
    Status status = _actorStatus(tokensOwner_, protector_, Role.PROTECTOR);
    return status > Status.PENDING;
  }

  function protectorsFor(address tokensOwner_) external view override returns (address[] memory) {
    return _listActiveActors(tokensOwner_, Role.PROTECTOR);
  }

  function acceptProposal(address tokensOwner_, bool accepted_) external {
    uint i = _validatePendingProtector(tokensOwner_, _msgSender());
    if (_ownersByProtector[_msgSender()] != address(0)) {
      // the transfer initializer has been associated to another owner in between the
      // set and the confirmation
      revert AssociatedToAnotherOwner();
    }
    if (accepted_) {
      _updateStatus(tokensOwner_, i, Role.PROTECTOR, Status.ACTIVE);
      _ownersByProtector[_msgSender()] = tokensOwner_;
    } else {
      _removeActorByIndex(tokensOwner_, i, Role.PROTECTOR);
    }
    emit ProtectorUpdated(tokensOwner_, _msgSender(), accepted_);
  }

  function resignAsProtectorFor(address tokensOwner_) external {
    (uint i, Status status) = _findProtector(tokensOwner_, _msgSender());
    if (status == Status.UNSET) {
      revert NotAProtector();
    } else if (status == Status.RESIGNED) {
      revert ResignationAlreadySubmitted();
    } else if (status == Status.ACTIVE) {
      _updateStatus(tokensOwner_, i, Role.PROTECTOR, Status.RESIGNED);
      emit ProtectorResigned(_msgSender(), _msgSender());
    } else {
      // it obtains similar results like not accepting a proposal
      _removeActorByIndex(tokensOwner_, i, Role.PROTECTOR);
    }
  }

  function acceptResignation(address protector_) external onlyTokensOwner {
    (uint i, Status status) = _findProtector(_msgSender(), protector_);
    if (status == Status.RESIGNED) {
      _removeActorByIndex(_msgSender(), i, Role.PROTECTOR);
    } else {
      revert ResignationNotSubmitted();
    }
  }

  function signedByProtector(address owner_, bytes32 hash, bytes memory signature) public view override returns (bool) {
    address signer = hash.recover(signature);
    (, Status status) = _findProtector(owner_, signer);
    return status > Status.UNSET;
  }

  function protectedTransfer(
    uint tokenId,
    address to,
    uint256 timestamp,
    uint validFor,
    bytes calldata signature
  ) external override onlyTokenOwner(tokenId) {
    validateTimestampAndSignature(
      ownerOf(tokenId),
      timestamp,
      validFor,
      _tokenUtils.hashTransferRequest(tokenId, to, timestamp, validFor),
      signature
    );
    _approvedTransfers[tokenId] = true;
    _transfer(_msgSender(), to, tokenId);
    delete _approvedTransfers[tokenId];
  }

  function isSignatureUsed(bytes calldata signature) public view override returns (bool) {
    return _usedSignatures[keccak256(signature)];
  }

  function setSignatureAsUsed(bytes calldata signature) public override {
    for (uint i = 0; i < _vaults.length; i++) {
      if (_vaults[i] == _msgSender()) {
        revert NotAFlexiVault();
      }
    }
    _usedSignatures[keccak256(signature)] = true;
  }

  function validateTimestampAndSignature(
    address tokenOwner_,
    uint256 timestamp,
    uint validFor,
    bytes32 hash,
    bytes calldata signature
  ) public override {
    if (timestamp > block.timestamp || timestamp < block.timestamp - validFor) revert TimestampInvalidOrExpired();
    if (!signedByProtector(tokenOwner_, hash, signature)) revert WrongDataOrNotSignedByProtector();
    if (isSignatureUsed(signature)) revert SignatureAlreadyUsed();
    setSignatureAsUsed(signature);
  }

  function invalidateSignatureFor(uint tokenId, bytes32 hash, bytes calldata signature) external override {
    address tokenOwner_ = ownerOf(tokenId);
    (, Status status) = _findProtector(ownerOf(tokenId), _msgSender());
    if (status < Status.ACTIVE) revert NotAProtector();
    if (!signedByProtector(tokenOwner_, hash, signature)) revert WrongDataOrNotSignedByProtector();
    setSignatureAsUsed(signature);
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
    if (_lockedProtectorsFor[tokensOwner_] == Status.RESIGNED) revert ProtectorsUnlockAlreadyStarted();
    // else is ACTIVE, since there is no PENDING status
    _lockedProtectorsFor[tokensOwner_] = Status.RESIGNED;
  }

  function approveUnlockProtectors(bool approved) external onlyTokensOwner {
    if (_lockedProtectorsFor[_msgSender()] != Status.RESIGNED) revert ProtectorsUnlockNotStarted();
    if (approved) {
      delete _lockedProtectorsFor[_msgSender()];
      emit ProtectorsLocked(_msgSender(), false);
    } else {
      // reverts the change from RESIGNED to ACTIVE
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
    if (operator == address(0)) revert NoZeroAddress();
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
  ) internal virtual override(ERC721, ERC721Enumerable) {
    if (!isTransferable(tokenId, from, to)) revert NotPermittedWhenProtectorsAreActive();
    delete _operators[tokenId];
    super._beforeTokenTransfer(from, to, tokenId, batchSize);
  }

  function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721Enumerable) returns (bool) {
    return interfaceId == type(IProtectedERC721).interfaceId || super.supportsInterface(interfaceId);
  }

  // safe recipients

  function _setSafeRecipient(address recipient, Level level) private {
    if (level == Level.NONE) {
      _removeActor(_msgSender(), recipient, Role.RECIPIENT);
    } else {
      _addActor(_msgSender(), recipient, Role.RECIPIENT, Status.ACTIVE, level);
    }
    emit SafeRecipientUpdated(_msgSender(), recipient, level);
  }

  function setSafeRecipient(address recipient, Level level) external override onlyTokensOwner {
    if (_countActiveProtectors(_msgSender()) > 0) revert NotPermittedWhenProtectorsAreActive();
    _setSafeRecipient(recipient, level);
  }

  function setProtectedSafeRecipient(
    address recipient,
    Level level,
    uint256 timestamp,
    uint validFor,
    bytes calldata signature
  ) external override onlyTokensOwner {
    validateTimestampAndSignature(
      _msgSender(),
      timestamp,
      validFor,
      _tokenUtils.hashRecipientRequest(_msgSender(), recipient, level, timestamp, validFor),
      signature
    );
    _setSafeRecipient(recipient, level);
  }

  function safeRecipientLevel(address tokenOwner_, address recipient) public view override returns (Level) {
    (, Actor memory actor) = _getActor(tokenOwner_, recipient, Role.RECIPIENT);
    return actor.level;
  }

  function getSafeRecipients(address tokenOwner_) external view override returns (Actor[] memory) {
    return _getActors(tokenOwner_, Role.RECIPIENT);
  }

  // IERC6454

  function isTransferable(uint256 tokenId, address from, address to) public view override returns (bool) {
    // Burnings and self transfers are not allowed
    if (to == address(0) || from == to) return false;
    // if from zero, it is minting
    else if (from == address(0)) return true;
    else {
      _requireMinted(tokenId);
      return
        _countActiveProtectors(ownerOf(tokenId)) == 0 ||
        _approvedTransfers[tokenId] ||
        safeRecipientLevel(ownerOf(tokenId), to) == Level.HIGH;
    }
  }

  // beneficiaries

  function _setBeneficiary(address beneficiary, Status status) private {
    if (status == Status.UNSET) {
      _removeActor(_msgSender(), beneficiary, Role.BENEFICIARY);
    } else {
      _addActor(_msgSender(), beneficiary, Role.BENEFICIARY, status, Level.NONE);
    }
    emit BeneficiaryUpdated(_msgSender(), beneficiary, status);
  }

  function setBeneficiary(address recipient, Status status) external onlyTokensOwner {
    if (_countActiveProtectors(_msgSender()) > 0) revert NotPermittedWhenProtectorsAreActive();
    _setBeneficiary(recipient, status);
  }

  function setProtectedBeneficiary(
    address beneficiary,
    Status status,
    uint256 timestamp,
    uint validFor,
    bytes calldata signature
  ) external onlyTokensOwner {
    validateTimestampAndSignature(
      _msgSender(),
      timestamp,
      validFor,
      _tokenUtils.hashBeneficiaryRequest(_msgSender(), beneficiary, status, timestamp, validFor),
      signature
    );
    _setBeneficiary(beneficiary, status);
  }

  function configureBeneficiary(uint quorum, uint proofOfLifeDurationInDays) external onlyTokensOwner {
    if (_countActiveProtectors(_msgSender()) > 0) revert NotPermittedWhenProtectorsAreActive();
    if (quorum == 0) revert QuorumCannotBeZero();
    if (quorum > _countActiveActorsByRole(_msgSender(), Role.BENEFICIARY)) revert QuorumCannotBeGreaterThanBeneficiaries();
    _beneficiaryConfs[_msgSender()] = BeneficiaryConf(quorum, proofOfLifeDurationInDays, block.timestamp);
    delete _beneficiariesRequests[_msgSender()];
  }

  function getBeneficiaries(address tokenOwner_) external view returns (Actor[] memory, BeneficiaryConf memory) {
    return (_getActors(tokenOwner_, Role.BENEFICIARY), _beneficiaryConfs[tokenOwner_]);
  }

  function proofOfLife() external onlyTokensOwner {
    if (_beneficiaryConfs[_msgSender()].proofOfLifeDurationInDays == 0) revert BeneficiaryNotConfigured();
    _beneficiaryConfs[_msgSender()].lastProofOfLife = block.timestamp;
    delete _beneficiariesRequests[_msgSender()];
  }

  function _hasApproved(address tokenOwner_) internal view returns (bool) {
    for (uint i = 0; i < _beneficiariesRequests[tokenOwner_].approvers.length; i++) {
      if (_msgSender() == _beneficiariesRequests[tokenOwner_].approvers[i]) {
        return true;
      }
    }
    return false;
  }

  function requestTransfer(address tokenOwner_, address beneficiaryRecipient) external {
    if (beneficiaryRecipient == address(0)) revert NoZeroAddress();
    if (_beneficiaryConfs[tokenOwner_].proofOfLifeDurationInDays == 0) revert BeneficiaryNotConfigured();
    (, Actor storage actor) = _getActor(tokenOwner_, _msgSender(), Role.BENEFICIARY);
    if (actor.status == Status.UNSET) revert NotABeneficiary();
    if (
      _beneficiaryConfs[tokenOwner_].lastProofOfLife + (_beneficiaryConfs[tokenOwner_].proofOfLifeDurationInDays * 3600) >
      block.timestamp
    ) revert NotExpiredYet();
    // the following prevents hostile beneficiaries from blocking the process not allowing them to reset the recipient
    if (_hasApproved(_msgSender())) revert RequestAlreadyApproved();
    // the beneficiary is proposing a new recipient
    if (_beneficiariesRequests[tokenOwner_].recipient != beneficiaryRecipient) {
      if (block.timestamp - _beneficiariesRequests[tokenOwner_].startedAt > 30 days) {
        // reset the request
        delete _beneficiariesRequests[tokenOwner_];
      } else revert InconsistentRecipient();
    }
    if (_beneficiariesRequests[tokenOwner_].recipient == address(0)) {
      _beneficiariesRequests[tokenOwner_].recipient = beneficiaryRecipient;
      _beneficiariesRequests[tokenOwner_].startedAt = block.timestamp;
      _beneficiariesRequests[tokenOwner_].approvers.push(_msgSender());
    } else if (!_hasApproved(_msgSender())) {
      _beneficiariesRequests[tokenOwner_].approvers.push(_msgSender());
    }
  }

  function inherit(address tokenOwner_) external {
    if (
      _beneficiariesRequests[tokenOwner_].recipient == _msgSender() &&
      _beneficiariesRequests[tokenOwner_].approvers.length >= _beneficiaryConfs[tokenOwner_].quorum
    ) {
      uint balance = balanceOf(tokenOwner_);
      uint[] memory tokenIds = new uint[](balance);
      for (uint i = 0; i < balance; i++) {
        tokenIds[i] = tokenOfOwnerByIndex(tokenOwner_, i);
      }
      for (uint i = 0; i < balance; i++) {
        _safeTransfer(tokenOwner_, _msgSender(), tokenIds[i], "");
      }
      emit Inherited(tokenOwner_, _msgSender(), balance);
    } else revert Unauthorized();
  }
}
