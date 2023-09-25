// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Author: Francesco Sullo <francesco@sullo.co>

import {ERC165, IERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {FlexiVault} from "../vaults/FlexiVault.sol";
import {IProtectedERC721} from "./IProtectedERC721.sol";
import {ProtectedERC721Errors} from "./ProtectedERC721Errors.sol";
import {ProtectedERC721Events} from "./ProtectedERC721Events.sol";
import {IVersioned} from "../utils/IVersioned.sol";
import {IERC6454} from "./IERC6454.sol";
import {Actors, IActors} from "./Actors.sol";
import {IActorsManager} from "./IActorsManager.sol";
import {FlexiVault} from "../vaults/FlexiVault.sol";
import {ISignatureValidator} from "../utils/ISignatureValidator.sol";

//import {console} from "hardhat/console.sol";

contract ActorsManager is IActorsManager, Actors, Ownable2Step, ERC165 {
  using ECDSA for bytes32;
  using Strings for uint256;

  FlexiVault public flexiVault;
  ISignatureValidator public signatureValidator;

  // the address of a second wallet required to validate the transfer of a token
  // the user can set up to 2 protectors
  // owner >> protector >> approved
  //  mapping(address => Protector[]) private _protectors;

  // the address of the owner given the second wallet required to start the transfer
  mapping(address => address) internal _ownersByProtector;

  // the tokens currently being transferred when a second wallet is set
  //  mapping(uint256 => ControlledTransfer) private _controlledTransfers;
  mapping(bytes32 => bool) internal _usedSignatures;

  mapping(address => BeneficiaryRequest) internal _beneficiariesRequests;

  mapping(address => BeneficiaryConf) internal _beneficiaryConfs;

  modifier onlyTokenOwner(uint256 tokenId) {
    if (flexiVault.ownerOf(tokenId) != _msgSender()) revert NotTheTokenOwner();
    _;
  }

  modifier onlyTokensOwner() {
    if (flexiVault.balanceOf(_msgSender()) == 0) revert NotATokensOwner();
    _;
  }

  function init(address crunaVault) external onlyOwner {
    if (!IERC165(crunaVault).supportsInterface(type(IProtectedERC721).interfaceId)) revert InvalidProtectedERC721();
    flexiVault = FlexiVault(crunaVault);
    if (address(flexiVault.actorsManager()) != address(this)) revert NotTheBondedProtectedERC721();
    signatureValidator = ISignatureValidator(flexiVault.signatureValidator());
  }

  function isActorsManager() external pure override returns (bytes4) {
    return ActorsManager.isActorsManager.selector;
  }

  function countActiveProtectors(address tokensOwner_) public view override returns (uint256) {
    return _countActiveActorsByRole(tokensOwner_, Role.PROTECTOR);
  }

  function findProtector(address tokensOwner_, address protector_) public view override returns (uint256, Status) {
    (uint256 i, IActors.Actor storage actor) = _getActor(tokensOwner_, protector_, Role.PROTECTOR);
    return (i, actor.status);
  }

  function isProtectorFor(address tokensOwner_, address protector_) public view returns (bool) {
    Status status = _actorStatus(tokensOwner_, protector_, Role.PROTECTOR);
    return status == Status.ACTIVE;
  }

  function hasProtectors(address tokensOwner_) public view override returns (address[] memory) {
    return _listActiveActors(tokensOwner_, Role.PROTECTOR);
  }

  function setProtector(
    address protector_,
    bool active,
    uint256 timestamp,
    uint256 validFor,
    bytes calldata signature
  ) external virtual override onlyTokensOwner {
    if (protector_ == address(0)) revert NoZeroAddress();
    _checkIfSignatureUsed(signature);
    isNotExpired(timestamp, validFor);
    address signer = signatureValidator.signSetProtector(_msgSender(), protector_, active, timestamp, validFor, signature);
    if (active) {
      if (_ownersByProtector[protector_] != address(0)) {
        if (_ownersByProtector[protector_] == _msgSender()) revert ProtectorAlreadySetByYou();
        else revert AssociatedToAnotherOwner();
      }
      Status status = _actorStatus(_msgSender(), protector_, Role.PROTECTOR);
      if (countActiveProtectors(_msgSender()) == 0) {
        if (protector_ != signer) revert WrongDataOrNotSignedByProposedProtector();
      } else {
        isSignerAProtector(_msgSender(), signer);
      }
      if (status != Status.UNSET) revert ProtectorAlreadySet();
      _addActor(_msgSender(), protector_, Role.PROTECTOR, Status.ACTIVE, Level.NONE);
      _ownersByProtector[protector_] = _msgSender();
    } else {
      isSignerAProtector(_msgSender(), signer);
      if (_ownersByProtector[protector_] != _msgSender()) revert NotYourProtector();
      (uint256 i, Status status) = findProtector(_msgSender(), protector_);
      if (status == Status.ACTIVE) {
        _removeActorByIndex(_msgSender(), i, Role.PROTECTOR);
      } else {
        revert NotAnActiveProtector();
      }
      if (status != Status.ACTIVE) revert ProtectorNotFound();
      delete _ownersByProtector[protector_];
    }
    emit ProtectorUpdated(_msgSender(), protector_, active);
  }

  function isNotExpired(uint256 timestamp, uint256 validFor) public view override {
    // solhint-disable-next-line not-rely-on-time
    if (timestamp > block.timestamp || timestamp < block.timestamp - validFor) revert TimestampInvalidOrExpired();
  }

  function isSignerAProtector(address tokenOwner_, address signer_) public view override {
    if (!isProtectorFor(tokenOwner_, signer_)) revert WrongDataOrNotSignedByProtector();
  }

  function signedByProtector(address owner_, bytes32 hash, bytes memory signature) public view override returns (bool) {
    address signer = hash.recover(signature);
    (, Status status) = findProtector(owner_, signer);
    return status > Status.UNSET;
  }

  function isSignatureUsed(bytes calldata signature) public view override returns (bool) {
    return _usedSignatures[keccak256(signature)];
  }

  function checkIfSignatureUsed(bytes calldata signature) public override {
    if (_msgSender() != address(flexiVault)) revert Forbidden();
    _checkIfSignatureUsed(signature);
  }

  function _checkIfSignatureUsed(bytes calldata signature) internal {
    if (_usedSignatures[keccak256(signature)]) revert SignatureAlreadyUsed();
    _usedSignatures[keccak256(signature)] = true;
  }

  function validateTimestampAndSignature(
    address tokenOwner_,
    uint256 timestamp,
    uint256 validFor,
    bytes32 hash,
    bytes calldata signature
  ) public view override {
    // solhint-disable-next-line not-rely-on-time
    if (timestamp > block.timestamp || timestamp < block.timestamp - validFor) revert TimestampInvalidOrExpired();
    if (!signedByProtector(tokenOwner_, hash, signature)) revert WrongDataOrNotSignedByProtector();
    if (isSignatureUsed(signature)) revert SignatureAlreadyUsed();
  }

  function invalidateSignatureFor(
    uint256 tokenId,
    bytes32 hash,
    bytes calldata signature
  ) external override onlyTokenOwner(tokenId) {
    address tokenOwner_ = flexiVault.ownerOf(tokenId);
    (, Status status) = findProtector(tokenOwner_, _msgSender());
    if (status < Status.ACTIVE) revert NotAProtector();
    if (!signedByProtector(tokenOwner_, hash, signature)) revert WrongDataOrNotSignedByProtector();
    _usedSignatures[keccak256(signature)] = true;
  }

  function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
    return interfaceId == type(IActorsManager).interfaceId || super.supportsInterface(interfaceId);
  }

  // safe recipients

  function setSafeRecipient(
    address recipient,
    Level level,
    uint256 timestamp,
    uint256 validFor,
    bytes calldata signature
  ) external override onlyTokensOwner {
    if (timestamp == 0) {
      if (countActiveProtectors(_msgSender()) > 0) revert NotPermittedWhenProtectorsAreActive();
    } else {
      address signer = signatureValidator.signRecipientRequest(
        _msgSender(),
        recipient,
        uint256(level),
        timestamp,
        validFor,
        signature
      );
      isNotExpired(timestamp, validFor);
      isSignerAProtector(_msgSender(), signer);
      _usedSignatures[keccak256(signature)] = true;
    }
    if (level == Level.NONE) {
      _removeActor(_msgSender(), recipient, Role.RECIPIENT);
    } else {
      _addActor(_msgSender(), recipient, Role.RECIPIENT, Status.ACTIVE, level);
    }
    emit SafeRecipientUpdated(_msgSender(), recipient, level);
  }

  function setSignatureAsUsed(bytes calldata signature) public override {
    if (_msgSender() != address(flexiVault)) revert Forbidden();
    _setSignatureAsUsed(signature);
  }

  function _setSignatureAsUsed(bytes calldata signature) internal {
    _usedSignatures[keccak256(signature)] = true;
  }

  function safeRecipientLevel(address tokenOwner_, address recipient) public view override returns (Level) {
    (, IActors.Actor memory actor) = _getActor(tokenOwner_, recipient, Role.RECIPIENT);
    return actor.level;
  }

  function getSafeRecipients(address tokenOwner_) external view override returns (IActors.Actor[] memory) {
    return _getActors(tokenOwner_, Role.RECIPIENT);
  }

  // beneficiaries

  function setBeneficiary(
    address beneficiary,
    Status status,
    uint256 timestamp,
    uint256 validFor,
    bytes calldata signature
  ) external override onlyTokensOwner {
    if (timestamp == 0) {
      if (countActiveProtectors(_msgSender()) > 0) revert NotPermittedWhenProtectorsAreActive();
    } else {
      address signer = signatureValidator.signBeneficiaryRequest(
        _msgSender(),
        beneficiary,
        uint256(status),
        timestamp,
        validFor,
        signature
      );
      isNotExpired(timestamp, validFor);
      isSignerAProtector(_msgSender(), signer);
      _usedSignatures[keccak256(signature)] = true;
    }
    if (status == Status.UNSET) {
      _removeActor(_msgSender(), beneficiary, Role.BENEFICIARY);
    } else {
      _addActor(_msgSender(), beneficiary, Role.BENEFICIARY, status, Level.NONE);
    }
    emit BeneficiaryUpdated(_msgSender(), beneficiary, status);
  }

  function configureBeneficiary(uint256 quorum, uint256 proofOfLifeDurationInDays) external onlyTokensOwner {
    if (countActiveProtectors(_msgSender()) > 0) revert NotPermittedWhenProtectorsAreActive();
    if (quorum == 0) revert QuorumCannotBeZero();
    if (quorum > _countActiveActorsByRole(_msgSender(), Role.BENEFICIARY)) revert QuorumCannotBeGreaterThanBeneficiaries();
    // solhint-disable-next-line not-rely-on-time
    _beneficiaryConfs[_msgSender()] = BeneficiaryConf(quorum, proofOfLifeDurationInDays, block.timestamp);
    delete _beneficiariesRequests[_msgSender()];
  }

  function getBeneficiaries(address tokenOwner_) external view returns (IActors.Actor[] memory, BeneficiaryConf memory) {
    return (_getActors(tokenOwner_, Role.BENEFICIARY), _beneficiaryConfs[tokenOwner_]);
  }

  function proofOfLife() external onlyTokensOwner {
    if (_beneficiaryConfs[_msgSender()].proofOfLifeDurationInDays == 0) revert BeneficiaryNotConfigured();
    // solhint-disable-next-line not-rely-on-time
    _beneficiaryConfs[_msgSender()].lastProofOfLife = block.timestamp;
    delete _beneficiariesRequests[_msgSender()];
  }

  function _hasApproved(address tokenOwner_) internal view returns (bool) {
    for (uint256 i = 0; i < _beneficiariesRequests[tokenOwner_].approvers.length; i++) {
      if (_msgSender() == _beneficiariesRequests[tokenOwner_].approvers[i]) {
        return true;
      }
    }
    return false;
  }

  function requestTransfer(address tokenOwner_, address beneficiaryRecipient) external {
    if (beneficiaryRecipient == address(0)) revert NoZeroAddress();
    if (_beneficiaryConfs[tokenOwner_].proofOfLifeDurationInDays == 0) revert BeneficiaryNotConfigured();
    (, IActors.Actor storage actor) = _getActor(tokenOwner_, _msgSender(), Role.BENEFICIARY);
    if (actor.status == Status.UNSET) revert NotABeneficiary();
    if (
      _beneficiaryConfs[tokenOwner_].lastProofOfLife + (_beneficiaryConfs[tokenOwner_].proofOfLifeDurationInDays * 1 hours) >
      // solhint-disable-next-line not-rely-on-time
      block.timestamp
    ) revert NotExpiredYet();
    // the following prevents hostile beneficiaries from blocking the process not allowing them to reset the recipient
    if (_hasApproved(tokenOwner_)) revert RequestAlreadyApproved();
    // a beneficiary is proposing a new recipient
    if (_beneficiariesRequests[tokenOwner_].recipient != beneficiaryRecipient) {
      // solhint-disable-next-line not-rely-on-time
      if (block.timestamp - _beneficiariesRequests[tokenOwner_].startedAt > 30 days) {
        // reset the request
        delete _beneficiariesRequests[tokenOwner_];
      } else revert InconsistentRecipient();
    }
    if (_beneficiariesRequests[tokenOwner_].recipient == address(0)) {
      _beneficiariesRequests[tokenOwner_].recipient = beneficiaryRecipient;
      // solhint-disable-next-line not-rely-on-time
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
      uint256 balance = flexiVault.balanceOf(tokenOwner_);
      uint256[] memory tokenIds = new uint256[](balance);
      for (uint256 i = 0; i < balance; i++) {
        tokenIds[i] = flexiVault.tokenOfOwnerByIndex(tokenOwner_, i);
      }
      for (uint256 i = 0; i < balance; i++) {
        flexiVault.managedTransfer(tokenIds[i], _msgSender());
      }
      emit Inherited(tokenOwner_, _msgSender(), balance);
      delete _beneficiariesRequests[tokenOwner_];
    } else revert Unauthorized();
  }
}
