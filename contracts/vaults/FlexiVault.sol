// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Author: Francesco Sullo <francesco@sullo.co>

import {ERC721, IERC721, IERC165} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {NFTOwned} from "../nft-owned/NFTOwned.sol";
import {IProtectedERC721} from "../protected-nft/IProtectedERC721.sol";
import {ITokenUtils} from "../utils/ITokenUtils.sol";
import {IERC6551Account} from "../ERC6551/IERC6551Account.sol";
import {IERC6551Registry} from "../ERC6551/IERC6551Registry.sol";
import {IERC6551Account} from "../ERC6551/IERC6551Account.sol";
import {TrusteeNFT} from "../ERC6551/TrusteeNFT.sol";
import {IVersioned} from "../utils/IVersioned.sol";
import {IFlexiVaultExtended} from "./IFlexiVaultExtended.sol";
import {IActors} from "../protected-nft/IActors.sol";

//import {console} from "hardhat/console.sol";

contract FlexiVault is IFlexiVaultExtended, IERC721Receiver, IVersioned, Ownable, NFTOwned, ReentrancyGuard {
  mapping(bytes32 => uint256) private _unconfirmedDeposits;

  // modifiers

  mapping(uint256 => bool) private _ejects;

  IERC6551Registry internal _registry;
  IERC6551Account public boundAccount;
  IERC6551Account public boundAccountUpgradeable;
  ITokenUtils internal _tokenUtils;
  TrusteeNFT public trustee;
  uint256 internal _salt;
  mapping(uint256 => address) internal _accountAddresses;
  bool private _initiated;
  IProtectedERC721 internal _protectedOwningToken;

  // The operators that can manage a specific tokenId.
  // Operators are not restricted to follow an owner, as protectors do.
  // The idea is that for any tokenId there can be just a few operators
  // so we do not risk to go out of gas when checking them.
  mapping(uint256 => address[]) private _operators;

  modifier onlyOwningTokenOwner(uint256 owningTokenId) {
    if (ownerOf(owningTokenId) != msg.sender) {
      revert NotTheOwningTokenOwner();
    }
    _;
  }

  modifier onlyOwningTokenOwnerOrOperator(uint256 owningTokenId) {
    if (ownerOf(owningTokenId) != msg.sender && !isOperatorFor(owningTokenId, msg.sender)) {
      revert NotTheOwningTokenOwnerOrOperatorFor();
    }
    _;
  }

  modifier onlyProtected() {
    if (_msgSender() != address(_protectedOwningToken)) revert OnlyProtectedOwningToken();
    _;
  }

  modifier onlyProtector(uint256 owningTokenId) {
    if (!_protectedOwningToken.isProtectorFor(ownerOf(owningTokenId), _msgSender())) revert NotTheProtector();
    _;
  }

  modifier onlyIfActiveAndOwningTokenNotApproved(uint256 owningTokenId) {
    if (_accountAddresses[owningTokenId] == address(0)) revert NotActivated();
    if (_ejects[owningTokenId]) revert AccountHasBeenEjected();
    // if the owningToken is approved for sale, the vaults cannot be modified to avoid scams
    if (_owningToken.getApproved(owningTokenId) != address(0)) revert ForbiddenWhenOwningTokenApprovedForSale();
    _;
  }

  // solhint-disable-next-line
  constructor(address owningToken, address tokenUtils) NFTOwned(owningToken) {
    _protectedOwningToken = IProtectedERC721(owningToken);
    if (!IERC165(_owningToken).supportsInterface(type(IProtectedERC721).interfaceId)) revert OwningTokenNotProtected();
    _salt = uint256(keccak256(abi.encodePacked(address(this), block.chainid, address(owningToken))));
    _tokenUtils = ITokenUtils(tokenUtils);
    if (_tokenUtils.isTokenUtils() != ITokenUtils.isTokenUtils.selector) revert InvalidTokenUtils();
  }

  /**
   * @dev {See IVersioned-version}
   */
  function version() external pure override returns (string memory) {
    return "1.0.0";
  }

  function onERC721Received(address, address, uint256, bytes memory) external pure returns (bytes4) {
    return this.onERC721Received.selector;
  }

  /**
   * @dev {See IFlexiVault-init}
   */
  function init(
    address registry,
    address payable boundAccount_,
    address payable boundAccountUpgradeable_
  ) external override onlyOwner {
    if (_initiated) revert AlreadyInitiated();
    if (!IERC165(registry).supportsInterface(type(IERC6551Registry).interfaceId)) revert InvalidRegistry();
    if (!IERC165(boundAccount_).supportsInterface(type(IERC6551Account).interfaceId)) revert InvalidAccount();
    if (!IERC165(boundAccountUpgradeable_).supportsInterface(type(IERC6551Account).interfaceId)) revert InvalidAccount();
    _registry = IERC6551Registry(registry);
    boundAccount = IERC6551Account(boundAccount_);
    boundAccountUpgradeable = IERC6551Account(boundAccountUpgradeable_);
    trustee = new TrusteeNFT();
    trustee.setMinter(address(this), true);
    trustee.transferOwnership(_msgSender());
    _initiated = true;
  }

  /**
   * @dev {See IFlexiVault-isFlexiVault}
   */
  function isFlexiVault() external pure override returns (bytes4) {
    return this.isFlexiVault.selector;
  }

  /**
   * @dev {See IFlexiVault-accountAddress}
   */
  function accountAddress(uint256 owningTokenId) external view override returns (address) {
    return _accountAddresses[owningTokenId];
  }

  /**
   * @dev {See IFlexiVault-activateAccount}
   */
  function activateAccount(uint256 owningTokenId, bool useUpgradeableAccount) external onlyOwningTokenOwner(owningTokenId) {
    if (!trustee.isMinter(address(this))) {
      // If the contract is no more the minter, there is a new version of the
      // vault and new users must use the new version.
      revert VaultHasBeenUpgraded();
    }
    if (_accountAddresses[owningTokenId] != address(0)) revert AccountAlreadyActive();
    address account = address(useUpgradeableAccount ? boundAccountUpgradeable : boundAccount);
    address walletAddress = _registry.account(account, block.chainid, address(trustee), owningTokenId, _salt);
    trustee.mint(address(this), owningTokenId);
    _accountAddresses[owningTokenId] = walletAddress;
    _registry.createAccount(account, block.chainid, address(trustee), owningTokenId, _salt, "");
  }

  function _getAccountBalance(uint256 owningTokenId, address asset, uint256 id) internal view returns (uint256) {
    address walletAddress = _accountAddresses[owningTokenId];
    if (asset == address(0)) {
      return walletAddress.balance;
    } else if (_tokenUtils.isERC20(asset)) {
      return IERC20(asset).balanceOf(walletAddress);
    } else if (_tokenUtils.isERC721(asset)) {
      return IERC721(asset).ownerOf(id) == walletAddress ? 1 : 0;
    } else if (_tokenUtils.isERC1155(asset)) {
      return IERC1155(asset).balanceOf(walletAddress, id);
    } else revert InvalidAsset();
  }

  function _isChangeAllowed(uint256 owningTokenId) internal view {
    if (_protectedOwningToken.protectorsFor(ownerOf(owningTokenId)).length > 0) revert NotAllowedWhenProtector();
  }

  function _transferToken(
    uint256 owningTokenId,
    TokenType tokenType,
    address to,
    address asset,
    uint256 id,
    uint256 amount
  ) internal {
    address walletAddress = _accountAddresses[owningTokenId];
    IERC6551Account accountInstance = IERC6551Account(payable(walletAddress));
    if (tokenType == TokenType.ETH) {
      accountInstance.executeCall(walletAddress, amount, "");
    } else if (tokenType == TokenType.ERC721) {
      accountInstance.executeCall(
        asset,
        0,
        abi.encodeWithSignature("safeTransferFrom(address,address,uint256)", walletAddress, to, id)
      );
    } else if (tokenType == TokenType.ERC1155) {
      accountInstance.executeCall(
        asset,
        0,
        abi.encodeWithSignature("safeTransferFrom(address,address,uint256,uint256,bytes)", walletAddress, to, id, amount, "")
      );
    } else if (tokenType == TokenType.ERC20) {
      accountInstance.executeCall(asset, 0, abi.encodeWithSignature("transfer(address,uint256)", to, amount));
    } else {
      revert InvalidAsset();
    }
  }

  function _withdrawAsset(
    uint256 owningTokenId,
    TokenType tokenType,
    address asset,
    uint256 id,
    uint256 amount,
    address beneficiary
  ) internal virtual {
    if (_owningToken.getApproved(owningTokenId) != address(0)) revert ForbiddenWhenOwningTokenApprovedForSale();
    if (amount == 0) revert InvalidAmount();
    uint256 balance = _getAccountBalance(owningTokenId, asset, id);
    if (balance < amount) revert InsufficientBalance();
    _transferToken(owningTokenId, tokenType, beneficiary != address(0) ? beneficiary : _msgSender(), asset, id, amount);
  }

  function _hasProtectorButNotSafeRecipient(uint256 owningTokenId, address recipient) internal view returns (bool) {
    return
      _protectedOwningToken.protectorsFor(ownerOf(owningTokenId)).length > 0 &&
      _protectedOwningToken.safeRecipientLevel(ownerOf(owningTokenId), recipient) == IActors.Level.NONE;
  }

  /**
   * @dev {See IFlexiVault-withdrawAssets}
   */
  function withdrawAssets(
    uint256 owningTokenId,
    TokenType[] memory tokenTypes,
    address[] memory assets,
    uint256[] memory ids,
    uint256[] memory amounts,
    address[] memory recipients,
    uint256 timestamp,
    uint256 validFor,
    bytes calldata signature
  )
    external
    override
    onlyOwningTokenOwnerOrOperator(owningTokenId)
    onlyIfActiveAndOwningTokenNotApproved(owningTokenId)
    nonReentrant
  {
    if (assets.length != ids.length || assets.length != amounts.length || assets.length != recipients.length)
      revert InconsistentLengths();
    // timestamp != 0 means calling it with a signature
    if (timestamp != 0) {
      bytes32 hash = _tokenUtils.hashWithdrawsRequest(
        owningTokenId,
        tokenTypes,
        assets,
        ids,
        amounts,
        recipients,
        timestamp,
        validFor
      );
      _protectedOwningToken.validateTimestampAndSignature(ownerOf(owningTokenId), timestamp, validFor, hash, signature);
    }
    for (uint256 i = 0; i < assets.length; i++) {
      // calling without a signature, then checking protectors and safe recipient level
      if (timestamp == 0 && _hasProtectorButNotSafeRecipient(owningTokenId, recipients[i])) {
        revert NotAllowedWhenProtector();
      }
      _withdrawAsset(owningTokenId, tokenTypes[i], assets[i], ids[i], amounts[i], recipients[i]);
    }
  }

  /**
   * @dev {See IFlexiVault-amountOf}
   */
  function amountOf(
    uint256 owningTokenId,
    address[] memory assets,
    uint256[] memory ids
  ) external view virtual override returns (uint256[] memory) {
    uint256[] memory amounts = new uint256[](assets.length);
    for (uint256 i = 0; i < assets.length; i++) {
      amounts[i] = _getAccountBalance(owningTokenId, assets[i], ids[i]);
    }
    return amounts;
  }

  function _ejectAccount(
    uint256 owningTokenId
  ) internal onlyOwningTokenOwner(owningTokenId) onlyIfActiveAndOwningTokenNotApproved(owningTokenId) {
    if (_ejects[owningTokenId]) revert AccountAlreadyEjected();
    trustee.safeTransferFrom(address(this), ownerOf(owningTokenId), owningTokenId);
    _ejects[owningTokenId] = true;
    emit BoundAccountEjected(owningTokenId);
  }

  /**
   * @dev {See IFlexiVault-ejectAccount}
   */
  function ejectAccount(uint256 owningTokenId) external override {
    if (_protectedOwningToken.protectorsFor(ownerOf(owningTokenId)).length > 0) revert NotAllowedWhenProtector();
    _ejectAccount(owningTokenId);
  }

  /**
   * @dev {See IFlexiVault-protectedEjectAccount}
   */
  function protectedEjectAccount(
    uint256 owningTokenId,
    uint256 timestamp,
    uint256 validFor,
    bytes calldata signature
  ) external override {
    bytes32 hash = _tokenUtils.hashEjectRequest(owningTokenId, timestamp, validFor);
    _protectedOwningToken.validateTimestampAndSignature(ownerOf(owningTokenId), timestamp, validFor, hash, signature);
    _ejectAccount(owningTokenId);
  }

  /**
   * @dev {See IFlexiVault-reInjectEjectedAccount}
   */
  function reInjectEjectedAccount(uint256 owningTokenId) external override onlyOwningTokenOwner(owningTokenId) {
    if (!_ejects[owningTokenId]) revert NotAPreviouslyEjectedAccount();
    // the contract must be approved
    trustee.transferFrom(ownerOf(owningTokenId), address(this), owningTokenId);
    delete _ejects[owningTokenId];
    emit EjectedBoundAccountReInjected(owningTokenId);
  }

  /**
   * @dev {See IFlexiVault-fixDirectlyInjectedAccount}
   */
  function fixDirectlyInjectedAccount(uint256 owningTokenId) external override onlyOwningTokenOwner(owningTokenId) {
    if (!_ejects[owningTokenId]) revert TheAccountHasNeverBeenEjected();
    if (trustee.ownerOf(owningTokenId) != address(this)) revert TheAccountIsNotOwnedByTheFlexiVault();
    delete _ejects[owningTokenId];
    emit EjectedBoundAccountReInjected(owningTokenId);
  }

  // operators

  function getOperatorForIndexIfExists(uint256 owningTokenId, address operator) public view override returns (bool, uint256) {
    for (uint256 i = 0; i < _operators[owningTokenId].length; i++) {
      if (_operators[owningTokenId][i] == operator) return (true, i);
    }
    return (false, 0);
  }

  function isOperatorFor(uint256 owningTokenId, address operator) public view override returns (bool) {
    for (uint256 i = 0; i < _operators[owningTokenId].length; i++) {
      if (_operators[owningTokenId][i] == operator) return true;
    }
    return false;
  }

  function setOperatorFor(uint256 owningTokenId, address operator, bool active) external onlyOwningTokenOwner(owningTokenId) {
    if (operator == address(0)) revert NoZeroAddress();
    (bool exists, uint256 i) = getOperatorForIndexIfExists(owningTokenId, operator);
    if (active) {
      if (exists) revert OperatorAlreadyActive();
      else _operators[owningTokenId].push(operator);
    } else {
      if (!exists) revert OperatorNotActive();
      else if (i != _operators[owningTokenId].length - 1) {
        _operators[owningTokenId][i] = _operators[owningTokenId][_operators[owningTokenId].length - 1];
      }
      _operators[owningTokenId].pop();
    }
    emit OperatorUpdated(owningTokenId, operator, active);
  }

  function removeOperatorsFor(uint256 owningTokenId) external onlyProtected {
    delete _operators[owningTokenId];
  }
}
