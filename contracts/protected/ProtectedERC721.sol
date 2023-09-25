// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Author: Francesco Sullo <francesco@sullo.co>

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {IProtectedERC721} from "./IProtectedERC721.sol";
import {ProtectedERC721Errors} from "./ProtectedERC721Errors.sol";
import {ProtectedERC721Events} from "./ProtectedERC721Events.sol";
import {IVersioned} from "../utils/IVersioned.sol";
import {IERC6454} from "./IERC6454.sol";
import {Actors, IActors} from "./Actors.sol";
import {ActorsManager, IActorsManager} from "./ActorsManager.sol";
import {ISignatureValidator} from "../utils/ISignatureValidator.sol";

//import {console} from "hardhat/console.sol";

abstract contract ProtectedERC721 is
  IProtectedERC721,
  ProtectedERC721Events,
  ProtectedERC721Errors,
  IERC6454,
  IVersioned,
  Actors,
  ERC721,
  ERC721Enumerable,
  Ownable2Step
{
  using ECDSA for bytes32;
  using Strings for uint256;

  IActorsManager public actorsManager;
  ISignatureValidator public signatureValidator;

  mapping(uint256 => bool) internal _approvedTransfers;

  modifier onlyProtectorFor(address owner_) {
    (uint256 i, Status status) = actorsManager.findProtector(owner_, _msgSender());
    if (status < Status.ACTIVE) revert NotAProtector();
    _;
  }

  modifier onlyProtectorForTokenId(uint256 tokenId_) {
    address owner_ = ownerOf(tokenId_);
    (uint256 i, Status status) = actorsManager.findProtector(owner_, _msgSender());
    if (status < Status.ACTIVE) revert NotAProtector();
    _;
  }

  modifier onlyTokenOwner(uint256 tokenId) {
    //    console.log(_ownerOf(tokenId), _msgSender());
    if (ownerOf(tokenId) != _msgSender()) revert NotTheTokenOwner();
    _;
  }

  modifier onlyActorManager() {
    if (address(actorsManager) != _msgSender()) revert NotTheActorManager();
    _;
  }

  modifier onlyTokensOwner() {
    if (balanceOf(_msgSender()) == 0) revert NotATokensOwner();
    _;
  }

  constructor(
    string memory name_,
    string memory symbol_,
    address actorsManager_,
    address signatureValidator_
  ) ERC721(name_, symbol_) {
    actorsManager = IActorsManager(actorsManager_);
    if (actorsManager.isActorsManager() != IActorsManager.isActorsManager.selector) revert InvalidActorsManager();
    signatureValidator = ISignatureValidator(signatureValidator_);
    if (signatureValidator.isSignatureValidator() != ISignatureValidator.isSignatureValidator.selector)
      revert InvalidSignatureValidator();
  }

  function protectedTransfer(
    uint256 tokenId,
    address to,
    uint256 timestamp,
    uint256 validFor,
    bytes calldata signature
  ) external override onlyTokenOwner(tokenId) {
    actorsManager.checkIfSignatureUsed(signature);
    actorsManager.isNotExpired(timestamp, validFor);
    address signer = signatureValidator.signTransferRequest(tokenId, to, timestamp, validFor, signature);
    actorsManager.isSignerAProtector(ownerOf(tokenId), signer);
    _approvedTransfers[tokenId] = true;
    _transfer(_msgSender(), to, tokenId);
    delete _approvedTransfers[tokenId];
  }

  function managedTransfer(uint256 tokenId, address to) external override onlyActorManager {
    _approvedTransfers[tokenId] = true;
    _approve(address(actorsManager), tokenId);
    safeTransferFrom(ownerOf(tokenId), to, tokenId);
    _transfer(ownerOf(tokenId), to, tokenId);
    delete _approvedTransfers[tokenId];
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId,
    uint256 batchSize
  ) internal virtual override(ERC721, ERC721Enumerable) {
    if (!isTransferable(tokenId, from, to)) revert NotTransferable();
    _cleanOperators(tokenId);
    super._beforeTokenTransfer(from, to, tokenId, batchSize);
  }

  function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721Enumerable) returns (bool) {
    return interfaceId == type(IProtectedERC721).interfaceId || super.supportsInterface(interfaceId);
  }

  // safe recipients
  // must be overriden by the inheriting contract
  function _cleanOperators(uint256 tokenId) internal virtual;

  // IERC6454

  function isTransferable(uint256 tokenId, address from, address to) public view override returns (bool) {
    // Burnings and self transfers are not allowed
    if (to == address(0) || from == to) return false;
    // if from zero, it is minting
    else if (from == address(0)) return true;
    else {
      _requireMinted(tokenId);
      return
        actorsManager.countActiveProtectors(ownerOf(tokenId)) == 0 ||
        _approvedTransfers[tokenId] ||
        actorsManager.safeRecipientLevel(ownerOf(tokenId), to) == Level.HIGH;
    }
  }
}
