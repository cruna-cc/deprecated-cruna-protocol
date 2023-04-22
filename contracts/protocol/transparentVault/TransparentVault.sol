// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.17;
pragma experimental ABIEncoderV2;

// Author: Francesco Sullo <francesco@sullo.co>

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "@cruna/ds-protocol/contracts/ERC721SubordinateUpgradeable.sol";

import "../interfaces/ITransparentVault.sol";
import "../interfaces/IProtector.sol";
import "../utils/ERC721Receiver.sol";
import "../utils/TokenUtils.sol";
import "../storage/EnumerableStorage.sol";

import "hardhat/console.sol";

contract TransparentVault is
  ITransparentVault,
  EnumerableStorage,
  ERC721Receiver,
  OwnableUpgradeable,
  ERC721SubordinateUpgradeable,
  ReentrancyGuardUpgradeable,
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

  mapping(bytes32 => uint256) private _unconfirmedDeposits;

  mapping(bytes32 => InitiatorAndTimestamp) private _restrictedTransfers;

  mapping(bytes32 => InitiatorAndTimestamp) private _restrictedWithdrawals;
  // modifiers

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

  modifier onlyIfProtectorNotApproved(uint256 protectorId) {
    // if the protector is approved for sale, the vault cannot be modified to avoid scams
    if (ERC721Upgradeable(dominantToken()).getApproved(protectorId) != address(0))
      revert ForbiddenWhenProtectorApprovedForSale();
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
      _save(protectorId, asset, id, int256(amount));
      emit Deposit(protectorId, asset, id, amount);
    } else if (_allowWithConfirmation[protectorId]) {
      _unconfirmedDeposits[keccak256(abi.encodePacked(protectorId, asset, id, amount, _msgSender()))] = block.timestamp;
      emit UnconfirmedDeposit(protectorId, asset, id, amount);
    } else revert NotAllowed();
  }

  function depositERC721(
    uint256 protectorId,
    address asset,
    uint256 id
  ) public override nonReentrant onlyIfProtectorNotApproved(protectorId) {
    _depositERC721(protectorId, asset, id);
  }

  function depositERC20(
    uint256 protectorId,
    address asset,
    uint256 amount
  ) public override nonReentrant onlyIfProtectorNotApproved(protectorId) {
    _depositERC20(protectorId, asset, amount);
  }

  function depositERC1155(
    uint256 protectorId,
    address asset,
    uint256 id,
    uint256 amount
  ) public override nonReentrant onlyIfProtectorNotApproved(protectorId) {
    _depositERC1155(protectorId, asset, id, amount);
  }

  function _depositERC721(
    uint256 protectorId,
    address asset,
    uint256 id
  ) internal {
    _validateAndEmitEvent(protectorId, asset, id, 1);
    // the following reverts if not an ERC721. We do not pre-check to save gas.
    IERC721Upgradeable(asset).safeTransferFrom(_msgSender(), address(this), id);
  }

  function _depositERC20(
    uint256 protectorId,
    address asset,
    uint256 amount
  ) internal {
    _validateAndEmitEvent(protectorId, asset, 0, amount);
    // the following reverts if not an ERC20
    bool transferred = IERC20Upgradeable(asset).transferFrom(_msgSender(), address(this), amount);
    if (!transferred) revert TransferFailed();
  }

  function _depositERC1155(
    uint256 protectorId,
    address asset,
    uint256 id,
    uint256 amount
  ) internal {
    _validateAndEmitEvent(protectorId, asset, id, amount);
    // the following reverts if not an ERC1155
    IERC1155Upgradeable(asset).safeTransferFrom(_msgSender(), address(this), id, amount, "");
  }

  function depositAssets(
    uint256 protectorId,
    address[] memory assets,
    uint256[] memory ids,
    uint256[] memory amounts
  ) external override nonReentrant onlyIfProtectorNotApproved(protectorId) {
    if (assets.length != ids.length || assets.length != amounts.length) revert InconsistentLengths();
    for (uint256 i = 0; i < assets.length; i++) {
      if (_tokenUtils.isERC20(assets[i])) {
        _depositERC20(protectorId, assets[i], amounts[i]);
      } else if (_tokenUtils.isERC721(assets[i])) {
        _depositERC721(protectorId, assets[i], ids[i]);
      } else if (_tokenUtils.isERC1155(assets[i])) {
        _depositERC1155(protectorId, assets[i], ids[i], amounts[i]);
      } else revert InvalidAsset();
    }
  }

  function _unconfirmedDepositExpired(uint256 timestamp) internal view returns (bool) {
    return timestamp + 1 weeks < block.timestamp;
  }

  function _protectorExists(uint256 protectorId) internal view returns (bool) {
    return IProtector(dominantToken()).exists(protectorId);
  }

  function confirmDeposit(
    uint256 protectorId,
    address asset,
    uint256 id,
    uint256 amount,
    address sender
  ) external override onlyProtectorOwner(protectorId) onlyIfProtectorNotApproved(protectorId) {
    bytes32 key = keccak256(abi.encodePacked(protectorId, asset, id, amount, sender));
    uint256 timestamp = _unconfirmedDeposits[key];
    if (timestamp == 0 || _unconfirmedDepositExpired(timestamp)) revert UnconfirmedDepositNotFoundOrExpired();
    _save(protectorId, asset, id, int256(amount));
    emit Deposit(protectorId, asset, id, amount);
    delete _unconfirmedDeposits[key];
  }

  function withdrawExpiredUnconfirmedDeposit(
    uint256 protectorId,
    address asset,
    uint256 id,
    uint256 amount
  ) external override nonReentrant {
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
    if (getAmount(protectorId, asset, id) < amount) revert InsufficientBalance();
    return key;
  }

  function _transferAsset(
    uint256 protectorId,
    uint256 recipientProtectorId,
    address asset,
    uint256 id,
    uint256 amount
  ) internal {
    if (recipientProtectorId > 0) {
      if (!_protectorExists(recipientProtectorId)) revert InvalidRecipient();
      _save(recipientProtectorId, asset, id, int256(amount));
    } // else the tokens is trashed
    _save(protectorId, asset, id, -int256(amount));
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
  ) external override onlyProtectorOwner(protectorId) onlyIfProtectorNotApproved(protectorId) {
    if (ownerOf(protectorId) != ownerOf(recipientProtectorId)) {
      _checkIfStartAllowed(protectorId);
    }
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
  ) external override onlyInitiator(protectorId) onlyIfProtectorNotApproved(protectorId) {
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
  ) external override onlyProtectorOwner(protectorId) onlyIfProtectorNotApproved(protectorId) {
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
    _save(protectorId, asset, id, -int256(amount));
    emit Withdrawal(protectorId, beneficiary, asset, id, amount);
    _transferToken(address(this), beneficiary, asset, id, amount);
  }

  function withdrawAsset(
    uint256 protectorId,
    address asset,
    uint256 id,
    uint256 amount,
    address beneficiary
  ) external override onlyProtectorOwner(protectorId) nonReentrant {
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
  ) external override onlyInitiator(protectorId) onlyIfProtectorNotApproved(protectorId) {
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
  ) external override onlyProtectorOwner(protectorId) nonReentrant onlyIfProtectorNotApproved(protectorId) {
    bytes32 key = keccak256(abi.encodePacked(protectorId, beneficiary, asset, id, amount));
    if (_restrictedWithdrawals[key].initiator == address(0)) revert WithdrawalNotFound();
    if (_restrictedWithdrawals[key].expiresAt < block.timestamp) revert Expired();
    delete _restrictedWithdrawals[key];
    _withdrawAsset(protectorId, beneficiary, asset, id, amount);
  }

  // External services who need to see what a transparent vault contains can call
  // the Cruna Web API to get the list of assets owned by a protector. Then, they can call
  // this view to validate the results.
  function amountOf(
    uint256 protectorId,
    address[] memory asset,
    uint256[] memory id
  ) external view override returns (uint256[] memory) {
    uint256[] memory amounts = new uint256[](asset.length);
    for (uint256 i = 0; i < asset.length; i++) {
      amounts[i] = getAmount(protectorId, asset[i], id[i]);
    }
    return amounts;
  }
}
