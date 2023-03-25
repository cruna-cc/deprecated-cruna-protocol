// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.17;

// Author: Francesco Sullo <francesco@sullo.co>

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@ndujalabs/erc721subordinate/contracts/ERC721SubordinateUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

import "../interfaces/ITransparentVault.sol";
import "../interfaces/IProtector.sol";
import "../utils/ERC721Receiver.sol";
import "../utils/TokenUtils.sol";

import "hardhat/console.sol";

contract TransparentVault is
  ITransparentVault,
  ERC721Receiver,
  OwnableUpgradeable,
  ERC721SubordinateUpgradeable,
  UUPSUpgradeable
{
  using StringsUpgradeable for uint256;

  TokenUtils private _tokenUtils;

  // By default, only the protector's owner can deposit assets
  // If allowAll is true, anyone can deposit assets
  mapping(uint256 => bool) private _allowAll;

  // Address that can deposit assets, if not the protector's owner
  mapping(uint256 => mapping(address => bool)) private _allowList;

  // if true, the deposit is accepted but the protector's owner must confirm the deposit.
  // If not confirmed within a certain time, the deposit is cancelled and
  // the asset can be claimed back by the depositor
  mapping(uint256 => bool) private _allowWithConfirmation;

  // allowList and allowWithConfirmation are not mutually exclusive
  // The protector can have an allowList and confirm deposits from other senders

  // asset => tokenId => protectorId
  // solhint-disable-next-line var-name-mixedcase
  mapping(address => mapping(uint256 => uint256)) private _ERC721Deposits;

  // asset => tokenId => protectorId => amount
  // solhint-disable-next-line var-name-mixedcase
  mapping(address => mapping(uint256 => mapping(uint256 => uint256))) private _ERC1155Deposits;

  // asset => protectorId => amount
  // solhint-disable-next-line var-name-mixedcase
  mapping(address => mapping(uint256 => uint256)) private _ERC20Deposits;

  mapping(bytes32 => uint256) private _unconfirmedDeposits;
  //  uint256 private _unconfirmedDepositsLength;

  mapping(bytes32 => InitiatorAndTimestamp) private _restrictedTransfers;

  mapping(bytes32 => InitiatorAndTimestamp) private _restrictedWithdrawals;
  // modifiers

  mapping(bytes32 => uint256) private _depositAmounts;

  modifier onlyProtectorOwner(uint256 protectorId) {
    if (ownerOf(protectorId) != msg.sender) {
      revert NotTheProtectorOwner();
    }
    _;
  }

  modifier onlyInitiator(uint256 protectorId) {
    if (IProtector(dominantToken()).initiatorFor(ownerOf(protectorId)) != _msgSender()) revert NotTheInitiator();
    _;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(address protector, string memory namePrefix) public initializer {
    __ERC721Subordinate_init(string(abi.encodePacked(namePrefix, " - Cruna Transparent Vault")), "CrunaTV", protector);
    __Ownable_init();
  }

  function initializeLibraries(address tokenLibAddress_) public initializer {}

  function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}

  function configure(
    uint256 protectorId,
    bool allowAll_,
    bool allowWithConfirmation_,
    address[] memory allowList_,
    bool[] memory allowListStatus_
  )
    external
    override
    // expirationTime
    onlyProtectorOwner(protectorId)
  {
    if (allowAll_ != _allowAll[protectorId]) {
      if (allowAll_) {
        _allowAll[protectorId] = true;
      } else {
        delete _allowAll[protectorId];
      }
      emit AllowAllUpdated(protectorId, allowAll_);
    }
    if (allowWithConfirmation_ != _allowWithConfirmation[protectorId]) {
      if (allowWithConfirmation_) {
        _allowWithConfirmation[protectorId] = true;
      } else {
        delete _allowWithConfirmation[protectorId];
      }
      emit AllowWithConfirmationUpdated(protectorId, allowWithConfirmation_);
    }
    if (allowList_.length > 0) {
      if (allowList_.length != allowListStatus_.length) revert InconsistentLengths();
      for (uint256 i = 0; i < allowList_.length; i++) {
        if (allowListStatus_[i] != _allowList[protectorId][allowList_[i]]) {
          if (allowListStatus_[i]) {
            _allowList[protectorId][allowList_[i]] = true;
          } else {
            delete _allowList[protectorId][allowList_[i]];
          }
          emit AllowListUpdated(protectorId, allowList_[i], allowListStatus_[i]);
        }
      }
    }
  }

  function setTokenUtils(address tokenUtils_) external onlyOwner {
    if (tokenUtils_ == address(0)) revert InvalidAddress();
    _tokenUtils = TokenUtils(tokenUtils_);
  }

  function _validateAndEmitEvent(
    uint256 protectorId,
    address asset,
    uint256 id,
    uint256 amount
  ) internal {
    if (ownerOf(protectorId) == _msgSender() || _allowAll[protectorId] || _allowList[protectorId][_msgSender()]) {
      _depositAmounts[keccak256(abi.encodePacked(protectorId, asset, id))] += amount;
      emit Deposit(protectorId, asset, id, amount);
    } else if (_allowWithConfirmation[protectorId]) {
      _unconfirmedDeposits[keccak256(abi.encodePacked(protectorId, asset, id, amount, _msgSender()))] = block.timestamp;
      emit UnconfirmedDeposit(protectorId, asset, id, amount);
      //        protectorId, _unconfirmedDepositsLength++);
    } else revert NotAllowed();
  }

  function depositERC721(
    uint256 protectorId,
    address asset,
    uint256 id
  ) external override {
    _validateAndEmitEvent(protectorId, asset, id, 1);
    // the following reverts if not an ERC721. We do not pre-check to save gas.
    IERC721Upgradeable(asset).safeTransferFrom(_msgSender(), address(this), id);
  }

  function depositERC20(
    uint256 protectorId,
    address asset,
    uint256 amount
  ) external override {
    _validateAndEmitEvent(protectorId, asset, 0, amount);
    // the following reverts if not an ERC20
    bool transferred = IERC20Upgradeable(asset).transferFrom(_msgSender(), address(this), amount);
    if (!transferred) revert TransferFailed();
  }

  function depositERC1155(
    uint256 protectorId,
    address asset,
    uint256 id,
    uint256 amount
  ) external override {
    _validateAndEmitEvent(protectorId, asset, id, amount);
    // the following reverts if not an ERC1155
    IERC1155Upgradeable(asset).safeTransferFrom(_msgSender(), address(this), id, amount, "");
  }

  function _unconfirmedDepositExpired(uint256 timestamp) internal view returns (bool) {
    return timestamp + 1 weeks < block.timestamp;
  }

  function confirmDeposit(
    uint256 protectorId,
    address asset,
    uint256 id,
    uint256 amount,
    address sender
  ) external override onlyProtectorOwner(protectorId) {
    bytes32 key = keccak256(abi.encodePacked(protectorId, asset, id, amount, sender));
    uint256 timestamp = _unconfirmedDeposits[key];
    if (timestamp == 0 || _unconfirmedDepositExpired(timestamp)) revert UnconfirmedDepositNotFoundOrExpired();
    _depositAmounts[keccak256(abi.encodePacked(protectorId, asset, id))] += amount;
    emit Deposit(protectorId, asset, id, amount);
    delete _unconfirmedDeposits[key];
  }

  // TODO add trash deposit function

  // TODO add batch functions

  function withdrawExpiredUnconfirmedDeposit(
    uint256 protectorId,
    address asset,
    uint256 id,
    uint256 amount
  ) external override {
    bytes32 key = keccak256(abi.encodePacked(protectorId, asset, id, amount, _msgSender()));
    uint256 timestamp = _unconfirmedDeposits[key];
    if (timestamp == 0) revert UnconfirmedDepositNotFoundOrExpired();
    if (!_unconfirmedDepositExpired(timestamp)) revert UnconfirmedDepositNotExpiredYet();
    delete _unconfirmedDeposits[key];
    _transferToken(address(this), _msgSender(), asset, id, amount);
  }

  function _checkIfCanTransfer(
    uint256 protectorId,
    address asset,
    uint256 id,
    uint256 amount
  ) internal view returns (bytes32) {
    if (amount == 0) revert InvalidAmount();
    bytes32 key = keccak256(abi.encodePacked(protectorId, asset, id));
    if (_depositAmounts[key] < amount) revert InsufficientBalance();
    return key;
  }

  function _transferAsset(
    uint256 protectorId,
    uint256 recipientProtectorId,
    address asset,
    uint256 id,
    uint256 amount
  ) internal {
    bytes32 key = _checkIfCanTransfer(protectorId, asset, id, amount);
    _depositAmounts[keccak256(abi.encodePacked(recipientProtectorId, asset, id))] += amount;
    if (_depositAmounts[key] - amount > 0) {
      _depositAmounts[key] -= amount;
    } else {
      delete _depositAmounts[key];
    }
    emit DepositTransfer(recipientProtectorId, asset, id, amount, protectorId);
  }

  function _checkIfStartAllowed(uint256 protectorId) internal view {
    if (IProtector(dominantToken()).hasInitiator(ownerOf(protectorId))) revert NotAllowedWhenInitiator();
  }

  // transfer asset to another protector
  function transferAsset(
    uint256 protectorId,
    uint256 recipientProtectorId,
    address asset,
    uint256 id,
    uint256 amount
  ) external override onlyProtectorOwner(protectorId) {
    if (ownerOf(protectorId) != ownerOf(recipientProtectorId)) {
      _checkIfStartAllowed(protectorId);
    }
    _checkIfChangeAllowed(protectorId);
    if (_tokenUtils.isERC721(asset)) {
      amount = 1;
    } else if (_tokenUtils.isERC20(asset)) {
      id = 0;
    }
    _transferAsset(protectorId, recipientProtectorId, asset, id, amount);
  }

  function startTransferAsset(
    uint256 protectorId,
    uint256 recipientProtectorId,
    address asset,
    uint256 id,
    uint256 amount,
    uint32 validFor
  ) external override onlyInitiator(protectorId) {
    _checkIfCanTransfer(protectorId, asset, id, amount);
    bytes32 key = keccak256(abi.encodePacked(protectorId, recipientProtectorId, asset, id, amount));
    if (_restrictedTransfers[key].initiator != address(0) || _restrictedTransfers[key].expiresAt > block.timestamp)
      revert AssetAlreadyBeingTransferred();
    _restrictedTransfers[
      keccak256(abi.encodePacked(protectorId, recipientProtectorId, asset, id, amount))
    ] = InitiatorAndTimestamp({initiator: _msgSender(), expiresAt: uint32(block.timestamp) + validFor});
    emit DepositTransferStarted(recipientProtectorId, asset, id, amount, protectorId);
  }

  function _checkIfChangeAllowed(uint256 protectorId) internal view {
    if (ERC721Upgradeable(dominantToken()).getApproved(protectorId) != address(0))
      revert ForbiddenWhenProtectorApprovedForSale();
  }

  function completeTransferAsset(
    uint256 protectorId,
    uint256 recipientProtectorId,
    address asset,
    uint256 id,
    uint256 amount
  ) external override onlyProtectorOwner(protectorId) {
    _checkIfChangeAllowed(protectorId);
    // we repeat the check because the user can try starting many transfers with different amounts
    _checkIfCanTransfer(protectorId, asset, id, amount);
    bytes32 key = keccak256(abi.encodePacked(protectorId, recipientProtectorId, asset, id, amount));
    if (
      _restrictedTransfers[key].initiator != IProtector(dominantToken()).initiatorFor(ownerOf(protectorId)) ||
      _restrictedTransfers[key].expiresAt < block.timestamp
    ) revert InvalidTransfer();
    _transferAsset(protectorId, recipientProtectorId, asset, id, amount);
    delete _restrictedTransfers[key];
  }

  function _transferToken(
    address from,
    address to,
    address asset,
    uint256 id,
    uint256 amount
  ) internal {
    if (_tokenUtils.isERC721(asset)) {
      IERC721Upgradeable(asset).safeTransferFrom(from, to, id);
    } else if (_tokenUtils.isERC1155(asset)) {
      IERC1155Upgradeable(asset).safeTransferFrom(from, to, id, amount, "");
    } else if (_tokenUtils.isERC20(asset)) {
      bool transferred = IERC20Upgradeable(asset).transfer(to, amount);
      if (!transferred) revert TransferFailed();
    } else {
      // should never happen
      revert InvalidAsset();
    }
  }

  function _withdrawAsset(
    uint256 protectorId,
    address beneficiary,
    address asset,
    uint256 id,
    uint256 amount
  ) internal {
    _checkIfChangeAllowed(protectorId);
    bytes32 key = _checkIfCanTransfer(protectorId, asset, id, amount);
    _transferToken(address(this), beneficiary, asset, id, amount);
    if (_depositAmounts[key] - amount > 0) {
      _depositAmounts[key] -= amount;
    } else {
      delete _depositAmounts[key];
    }
  }

  function withdrawAsset(
    uint256 protectorId,
    address asset,
    uint256 id,
    uint256 amount,
    address beneficiary
  ) external override onlyProtectorOwner(protectorId) {
    _checkIfStartAllowed(protectorId);
    _withdrawAsset(protectorId, beneficiary != address(0) ? beneficiary : _msgSender(), asset, id, amount);
  }

  function startWithdrawal(
    uint256 protectorId,
    address asset,
    uint256 id,
    uint256 amount,
    uint32 validFor,
    address beneficiary
  ) external override onlyInitiator(protectorId) {
    _checkIfCanTransfer(protectorId, asset, id, amount);
    bytes32 key = keccak256(abi.encodePacked(protectorId, beneficiary, asset, id, amount));
    if (_restrictedWithdrawals[key].initiator != address(0) && _restrictedWithdrawals[key].expiresAt > block.timestamp)
      revert AssetAlreadyBeingWithdrawn();
    _restrictedWithdrawals[key] = InitiatorAndTimestamp({
      initiator: _msgSender(),
      expiresAt: uint32(block.timestamp) + validFor
    });
    emit WithdrawalStarted(protectorId, beneficiary, asset, id, amount);
  }

  function completeWithdrawal(
    uint256 protectorId,
    address asset,
    uint256 id,
    uint256 amount,
    address beneficiary
  ) external override onlyProtectorOwner(protectorId) {
    bytes32 key = keccak256(abi.encodePacked(protectorId, beneficiary, asset, id, amount));
    if (_restrictedWithdrawals[key].initiator == address(0)) revert WithdrawalNotFound();
    if (_restrictedWithdrawals[key].expiresAt < block.timestamp) revert Expired();
    _withdrawAsset(protectorId, beneficiary, asset, id, amount);
    delete _restrictedWithdrawals[key];
  }

  function ownedAssetAmount(
    uint256 protectorId,
    address asset,
    uint256 id
  ) external view override returns (uint256) {
    return _depositAmounts[keccak256(abi.encodePacked(protectorId, asset, id))];
  }
}
