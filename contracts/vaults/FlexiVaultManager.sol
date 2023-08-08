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
import {FlexiVault} from "./FlexiVault.sol";
import {ITokenUtils} from "../utils/ITokenUtils.sol";
import {IProtectedERC721} from "../protected/IProtectedERC721.sol";
import {IERC6551AccountExecutable} from "../ERC6551/interfaces/IERC6551AccountExecutable.sol";
import {IERC6551Account} from "../ERC6551/interfaces/IERC6551Account.sol";
import {IERC6551Executable} from "../ERC6551/interfaces/IERC6551Executable.sol";
import {IERC6551Registry} from "../ERC6551/interfaces/IERC6551Registry.sol";
import {Trustee, ITrustee} from "../ERC6551/Trustee.sol";
import {IVersioned} from "../utils/IVersioned.sol";
import {IFlexiVaultManagerExtended} from "./IFlexiVaultManagerExtended.sol";
import {IActors} from "../protected/IActors.sol";

//import {console} from "hardhat/console.sol";

contract FlexiVaultManager is IFlexiVaultManagerExtended, IERC721Receiver, IVersioned, Ownable, NFTOwned, ReentrancyGuard {
  mapping(bytes32 => uint256) private _unconfirmedDeposits;

  // modifiers

  IERC6551Registry internal _registry;
  IERC6551AccountExecutable public boundAccount;
  IERC6551AccountExecutable public boundAccountUpgradeable;
  ITokenUtils public tokenUtils;
  Trustee public trustee;

  mapping(uint => Trustee) public previousTrustees;
  uint public previousTrusteesCount;

  uint256 internal _salt;
  mapping(uint256 => address) internal _accountAddresses;
  bool internal _initiated;
  FlexiVault internal _vault;
  mapping(uint256 => AccountStatus) internal _accountStatuses;

  // The operators that can manage a specific tokenId.
  // Operators are not restricted to follow an owner, as protectors do.
  // The idea is that for any tokenId there can be just a few operators
  // so we do not risk to go out of gas when checking them.
  mapping(uint256 => address[]) internal _operators;

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

  modifier onlyVault() {
    if (_msgSender() != address(_vault)) revert OnlyVault();
    _;
  }

  modifier onlyProtector(uint256 owningTokenId) {
    if (!_vault.actorsManager().isProtectorFor(ownerOf(owningTokenId), _msgSender())) revert NotTheProtector();
    _;
  }

  modifier onlyIfActiveAndOwningTokenNotApproved(uint256 owningTokenId) {
    if (_accountAddresses[owningTokenId] == address(0)) revert NotActivated();
    if (trustee.ownerOf(owningTokenId) != address(this)) revert AccountHasBeenEjected();
    // if the owningToken is approved for sale, the vaults cannot be modified to avoid scams
    if (_owningToken.getApproved(owningTokenId) != address(0)) revert ForbiddenWhenOwningTokenApprovedForSale();
    _;
  }

  // solhint-disable-next-line
  constructor(address owningToken, address tokenUtils_) NFTOwned(owningToken) {
    _vault = FlexiVault(owningToken);
    if (!IERC165(_owningToken).supportsInterface(type(IProtectedERC721).interfaceId)) revert OwningTokenNotProtected();
    _salt = uint256(keccak256(abi.encodePacked(address(this), block.chainid, address(owningToken))));
    tokenUtils = ITokenUtils(tokenUtils_);
    if (tokenUtils.isTokenUtils() != ITokenUtils.isTokenUtils.selector) revert InvalidTokenUtils();
  }

  /**
   * @dev {See IVersioned-version}
   */
  function version() external pure virtual override returns (string memory) {
    return "1.0.0";
  }

  function onERC721Received(address, address, uint256, bytes memory) external pure virtual returns (bytes4) {
    return this.onERC721Received.selector;
  }

  /**
   * @dev {See IFlexiVaultManager.sol-init}
   */
  function init(
    address registry,
    address payable boundAccount_,
    address payable boundAccountUpgradeable_
  ) external virtual override onlyOwner {
    if (_initiated) revert AlreadyInitiated();
    if (!IERC165(registry).supportsInterface(type(IERC6551Registry).interfaceId)) revert InvalidRegistry();
    if (
      !IERC165(boundAccount_).supportsInterface(type(IERC6551Account).interfaceId) ||
      !IERC165(boundAccount_).supportsInterface(type(IERC6551Executable).interfaceId)
    ) revert InvalidAccount();
    if (
      !IERC165(boundAccountUpgradeable_).supportsInterface(type(IERC6551Account).interfaceId) ||
      !IERC165(boundAccountUpgradeable_).supportsInterface(type(IERC6551Executable).interfaceId)
    ) revert InvalidAccount();
    _registry = IERC6551Registry(registry);
    boundAccount = IERC6551AccountExecutable(boundAccount_);
    boundAccountUpgradeable = IERC6551AccountExecutable(boundAccountUpgradeable_);
    trustee = new Trustee();
    _initiated = true;
  }

  function setPreviousTrustees(address[] calldata) external virtual override {
    revert NotImplemented();
  }

  /**
   * @dev {See IFlexiVaultManager.sol-isFlexiVaultManager}
   */
  function isFlexiVaultManager() external pure virtual override returns (bytes4) {
    return this.isFlexiVaultManager.selector;
  }

  /**
   * @dev {See IFlexiVaultManager.sol-accountAddress}
   */
  function accountAddress(uint256 owningTokenId) external view override returns (address) {
    return _accountAddresses[owningTokenId];
  }

  /**
   * @dev {See IFlexiVaultManager.sol-activateAccount}
   */
  function activateAccount(uint256 owningTokenId, bool useUpgradeableAccount) external virtual onlyVault {
    address account = address(useUpgradeableAccount ? boundAccountUpgradeable : boundAccount);
    address walletAddress = _registry.account(account, block.chainid, address(trustee), owningTokenId, _salt);
    // revert if already activated
    trustee.mint(address(this), owningTokenId);
    _accountAddresses[owningTokenId] = walletAddress;
    _registry.createAccount(account, block.chainid, address(trustee), owningTokenId, _salt, "");
    _accountStatuses[owningTokenId] = AccountStatus.ACTIVE;
    emit BoundAccountActivated(owningTokenId, walletAddress);
  }

  /**
   * @dev {See IFlexiVaultManager.sol-depositAssets}
   */
  function depositAssets(
    uint256 owningTokenId,
    TokenType[] memory tokenTypes,
    address[] memory assets,
    uint256[] memory ids,
    uint256[] memory amounts,
    address sender
  ) external payable virtual override nonReentrant onlyVault {
    if (assets.length != ids.length || assets.length != amounts.length || assets.length != tokenTypes.length)
      revert InconsistentLengths();
    for (uint256 i = 0; i < assets.length; i++) {
      if (tokenTypes[i] == TokenType.ETH) {
        if (msg.value == 0) revert NoETH();
        (bool success, ) = payable(_accountAddresses[owningTokenId]).call{value: msg.value}("");
        if (!success) revert ETHDepositFailed();
      } else if (tokenTypes[i] == TokenType.ERC20) {
        bool transferred = IERC20(assets[i]).transferFrom(sender, _accountAddresses[owningTokenId], amounts[i]);
        if (!transferred) revert TransferFailed();
      } else if (tokenTypes[i] == TokenType.ERC721) {
        IERC721(assets[i]).safeTransferFrom(sender, _accountAddresses[owningTokenId], ids[i]);
      } else if (tokenTypes[i] == TokenType.ERC1155) {
        IERC1155(assets[i]).safeTransferFrom(sender, _accountAddresses[owningTokenId], ids[i], amounts[i], "");
      } else revert InvalidAsset();
    }
  }

  function _getAccountBalance(uint256 owningTokenId, address asset, uint256 id) internal view returns (uint256) {
    address walletAddress = _accountAddresses[owningTokenId];
    if (asset == address(0)) {
      return walletAddress.balance;
    } else if (tokenUtils.isERC20(asset)) {
      return IERC20(asset).balanceOf(walletAddress);
    } else if (tokenUtils.isERC721(asset)) {
      return IERC721(asset).ownerOf(id) == walletAddress ? 1 : 0;
    } else if (tokenUtils.isERC1155(asset)) {
      return IERC1155(asset).balanceOf(walletAddress, id);
    } else revert InvalidAsset();
  }

  function _isChangeAllowed(uint256 owningTokenId) internal view {
    if (_vault.actorsManager().hasProtectors(ownerOf(owningTokenId)).length > 0) revert NotAllowedWhenProtector();
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
    IERC6551AccountExecutable accountInstance = IERC6551AccountExecutable(payable(walletAddress));
    if (tokenType == TokenType.ETH) {
      accountInstance.execute(walletAddress, amount, "", 0);
    } else if (tokenType == TokenType.ERC721) {
      accountInstance.execute(
        asset,
        0,
        abi.encodeWithSignature("safeTransferFrom(address,address,uint256)", walletAddress, to, id),
        0
      );
    } else if (tokenType == TokenType.ERC1155) {
      accountInstance.execute(
        asset,
        0,
        abi.encodeWithSignature("safeTransferFrom(address,address,uint256,uint256,bytes)", walletAddress, to, id, amount, ""),
        0
      );
    } else if (tokenType == TokenType.ERC20) {
      accountInstance.execute(asset, 0, abi.encodeWithSignature("transfer(address,uint256)", to, amount), 0);
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
    address beneficiary,
    address sender
  ) internal virtual {
    if (_owningToken.getApproved(owningTokenId) != address(0)) revert ForbiddenWhenOwningTokenApprovedForSale();
    if (amount == 0) revert InvalidAmount();
    uint256 balance = _getAccountBalance(owningTokenId, asset, id);
    if (balance < amount) revert InsufficientBalance();
    _transferToken(owningTokenId, tokenType, beneficiary != address(0) ? beneficiary : sender, asset, id, amount);
  }

  function _hasProtectorButNotSafeRecipient(uint256 owningTokenId, address recipient) internal view returns (bool) {
    return
      _vault.actorsManager().hasProtectors(ownerOf(owningTokenId)).length > 0 &&
      _vault.actorsManager().safeRecipientLevel(ownerOf(owningTokenId), recipient) == IActors.Level.NONE;
  }

  /**
   * @dev {See IFlexiVaultManager.sol-withdrawAssets}
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
    bytes calldata signature,
    address sender
  ) external virtual override onlyVault {
    if (ownerOf(owningTokenId) != sender && !isOperatorFor(owningTokenId, sender)) {
      revert NotTheOwningTokenOwnerOrOperatorFor();
    }
    if (assets.length != ids.length || assets.length != amounts.length || assets.length != recipients.length)
      revert InconsistentLengths();
    // timestamp != 0 means calling it with a signature
    if (timestamp != 0) {
      bytes32 hash = tokenUtils.hashWithdrawsRequest(
        owningTokenId,
        tokenTypes,
        assets,
        ids,
        amounts,
        recipients,
        timestamp,
        validFor
      );
      _vault.actorsManager().validateTimestampAndSignature(ownerOf(owningTokenId), timestamp, validFor, hash, signature);
      _vault.setSignatureAsUsed(signature);
    }
    for (uint256 i = 0; i < assets.length; i++) {
      // calling without a signature, then checking protectors and safe recipient level
      if (timestamp == 0 && _hasProtectorButNotSafeRecipient(owningTokenId, recipients[i])) {
        revert NotAllowedWhenProtector();
      }
      _withdrawAsset(owningTokenId, tokenTypes[i], assets[i], ids[i], amounts[i], recipients[i], sender);
    }
  }

  /**
   * @dev {See IFlexiVaultManager.sol-amountOf}
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

  /**
   * @dev {See IFlexiVaultManager.sol-ejectAccount}
   */
  function ejectAccount(uint256 owningTokenId) external virtual override onlyVault {
    trustee.safeTransferFrom(address(this), ownerOf(owningTokenId), owningTokenId);
    // we are ejecting a previously reInjected account
    delete _accountStatuses[owningTokenId]; // equal to = AccountStatus.INACTIVE;
    emit BoundAccountEjected(owningTokenId);
  }

  /**
   * @dev {See IFlexiVaultManager.sol-reInjectEjectedAccount}
   */
  // In version 1 you can only reinject previously ejected accounts
  function reInjectEjectedAccount(uint256 owningTokenId) public virtual override onlyVault {
    _accountStatuses[owningTokenId] = AccountStatus.ACTIVE;
    emit EjectedBoundAccountReInjected(owningTokenId);
  }

  function reInjectEjectedAccount(uint256 owningTokenId, address accountAddress_) public virtual onlyVault {
    _accountStatuses[owningTokenId] = AccountStatus.ACTIVE;
    if (_accountAddresses[owningTokenId] == address(0)) {
      if (accountAddress_ == address(0)) revert InvalidAccountAddress();
      _accountAddresses[owningTokenId] = accountAddress_;
    }
    emit EjectedBoundAccountReInjected(owningTokenId);
  }

  /**
   * @dev {See IFlexiVaultManager.sol-fixDirectlyInjectedAccount}
   */
  function fixDirectlyInjectedAccount(uint256 owningTokenId) external virtual override onlyVault {
    if (trustee.ownerOf(owningTokenId) == address(this)) {
      if (_accountStatuses[owningTokenId] == AccountStatus.ACTIVE) revert NotAPreviouslyEjectedAccount();
      else {
        _accountStatuses[owningTokenId] = AccountStatus.ACTIVE;
      }
    } else revert TheAccountIsNotOwnedByTheFlexiVaultManager();
    emit EjectedBoundAccountReInjected(owningTokenId);
  }

  // operators

  function getOperatorForIndexIfExists(
    uint256 owningTokenId,
    address operator
  ) public view virtual override returns (bool, uint256) {
    // not an out-of-gas risk because there should be only a few operators
    for (uint256 i = 0; i < _operators[owningTokenId].length; i++) {
      if (_operators[owningTokenId][i] == operator) return (true, i);
    }
    return (false, 0);
  }

  function isOperatorFor(uint256 owningTokenId, address operator) public view virtual override returns (bool) {
    // not an out-of-gas risk because there should be only a few operators
    for (uint256 i = 0; i < _operators[owningTokenId].length; i++) {
      if (_operators[owningTokenId][i] == operator) return true;
    }
    return false;
  }

  function setOperatorFor(
    uint256 owningTokenId,
    address operator,
    bool active
  ) external virtual onlyOwningTokenOwner(owningTokenId) {
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

  function removeOperatorsFor(uint256 owningTokenId) external virtual onlyVault {
    delete _operators[owningTokenId];
  }
}
