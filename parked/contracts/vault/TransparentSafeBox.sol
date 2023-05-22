// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Author: Francesco Sullo <francesco@sullo.co>

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155ReceiverUpgradeable.sol";

import "../nft-owned/NFTOwnedUpgradeable.sol";
import "./ITransparentSafeBox.sol";
import "../protected-nft/IProtectedERC721.sol";
import "../utils/TokenUtils.sol";

//import "hardhat/console.sol";

contract TransparentSafeBox is
  ITransparentVault,
  IERC721ReceiverUpgradeable,
  IERC1155ReceiverUpgradeable,
  ContextUpgradeable,
  NFTOwnedUpgradeable,
  ReentrancyGuardUpgradeable,
  TokenUtils
{
  // By default, only the owningToken's owner can deposit assets
  // If allowAll is true, anyone can deposit assets
  mapping(uint256 => bool) private _allowAll;

  // Address that can deposit assets, if not the owningToken's owner
  mapping(uint256 => mapping(address => bool)) private _allowList;

  // if true, the deposit is accepted but the owningToken's owner must confirm the deposit.
  // If not confirmed within a certain time, the deposit is cancelled and
  // the asset can be claimed back by the depositor
  mapping(uint256 => bool) private _allowWithConfirmation;

  // allowList and allowWithConfirmation are not mutually exclusive
  // The owningToken can have an allowList and confirm deposits from other senders

  mapping(bytes32 => uint256) private _unconfirmedDeposits;

  mapping(bytes32 => ProtectorAndTimestamp) private _restrictedTransfers;

  mapping(bytes32 => ProtectorAndTimestamp) private _restrictedWithdrawals;
  // modifiers

  mapping(bytes32 => uint256) private _depositAmounts;

  bool internal _owningTokenIsProtected;

  modifier onlyOwningTokenOwner(uint256 owningTokenId) {
    if (ownerOf(owningTokenId) != msg.sender) {
      revert NotTheOwningTokenOwner();
    }
    _;
  }

  modifier onlyProtector(uint256 owningTokenId) {
    if (
      !_owningTokenIsProtected || IProtectedERC721(address(_owningToken)).protectorFor(ownerOf(owningTokenId)) != _msgSender()
    ) revert NotTheProtector();
    _;
  }

  modifier onlyIfOwningTokenNotApproved(uint256 owningTokenId) {
    // if the owningToken is approved for sale, the vault cannot be modified to avoid scams
    if (_owningToken.getApproved(owningTokenId) != address(0)) revert ForbiddenWhenOwningTokenApprovedForSale();
    _;
  }

  // solhint-disable-next-line
  function __TransparentVault_init(address owningToken) internal onlyInitializing {
    __NFTOwned_init(owningToken);
    if (_owningToken.supportsInterface(type(IProtectedERC721).interfaceId)) {
      _owningTokenIsProtected = true;
    }
    __ReentrancyGuard_init();
  }

  function supportsInterface(
    bytes4 interfaceId
  ) public view virtual override(IERC165Upgradeable, NFTOwnedUpgradeable) returns (bool) {
    return
      interfaceId == type(IERC721ReceiverUpgradeable).interfaceId ||
      interfaceId == type(IERC1155ReceiverUpgradeable).interfaceId ||
      super.supportsInterface(interfaceId);
  }

  function onERC721Received(address, address, uint256, bytes calldata) public pure override returns (bytes4) {
    return this.onERC721Received.selector;
  }

  function onERC1155Received(address, address, uint256, uint256, bytes memory) public virtual returns (bytes4) {
    return this.onERC1155Received.selector;
  }

  function onERC1155BatchReceived(
    address,
    address,
    uint256[] memory,
    uint256[] memory,
    bytes memory
  ) public virtual returns (bytes4) {
    return this.onERC1155BatchReceived.selector;
  }

  function configure(
    uint256 owningTokenId,
    bool allowAll_,
    bool allowWithConfirmation_,
    address[] memory allowList_,
    bool[] memory allowListStatus_
  )
    external
    override
    // expirationTime
    onlyOwningTokenOwner(owningTokenId)
  {
    if (allowAll_ != _allowAll[owningTokenId]) {
      if (allowAll_) {
        _allowAll[owningTokenId] = true;
      } else {
        delete _allowAll[owningTokenId];
      }
      emit AllowAllUpdated(owningTokenId, allowAll_);
    }
    if (allowWithConfirmation_ != _allowWithConfirmation[owningTokenId]) {
      if (allowWithConfirmation_) {
        _allowWithConfirmation[owningTokenId] = true;
      } else {
        delete _allowWithConfirmation[owningTokenId];
      }
      emit AllowWithConfirmationUpdated(owningTokenId, allowWithConfirmation_);
    }
    if (allowList_.length > 0) {
      if (allowList_.length != allowListStatus_.length) revert InconsistentLengths();
      for (uint256 i = 0; i < allowList_.length; i++) {
        if (allowListStatus_[i] != _allowList[owningTokenId][allowList_[i]]) {
          if (allowListStatus_[i]) {
            _allowList[owningTokenId][allowList_[i]] = true;
          } else {
            delete _allowList[owningTokenId][allowList_[i]];
          }
          emit AllowListUpdated(owningTokenId, allowList_[i], allowListStatus_[i]);
        }
      }
    }
  }

  function _addAmountToDeposit(uint owningTokenId, address asset, uint id, uint amount) internal virtual {
    _depositAmounts[keccak256(abi.encodePacked(owningTokenId, asset, id))] += amount;
  }

  function _validateAndEmitEvent(uint256 owningTokenId, address asset, uint256 id, uint256 amount) internal {
    if (ownerOf(owningTokenId) == _msgSender() || _allowAll[owningTokenId] || _allowList[owningTokenId][_msgSender()]) {
      _addAmountToDeposit(owningTokenId, asset, id, amount);
      emit Deposit(owningTokenId, asset, id, amount);
    } else if (_allowWithConfirmation[owningTokenId]) {
      _unconfirmedDeposits[keccak256(abi.encodePacked(owningTokenId, asset, id, amount, _msgSender()))] = block.timestamp;
      emit UnconfirmedDeposit(owningTokenId, asset, id, amount);
    } else revert NotAllowed();
  }

  function depositETH(uint256 owningTokenId) external payable override {
    if (msg.value == 0) revert NoETH();
    _validateAndEmitEvent(owningTokenId, address(0), 0, msg.value);
  }

  function depositERC721(
    uint256 owningTokenId,
    address asset,
    uint256 id
  ) public override nonReentrant onlyIfOwningTokenNotApproved(owningTokenId) {
    _depositERC721(owningTokenId, asset, id);
  }

  function depositERC20(
    uint256 owningTokenId,
    address asset,
    uint256 amount
  ) public override nonReentrant onlyIfOwningTokenNotApproved(owningTokenId) {
    _depositERC20(owningTokenId, asset, amount);
  }

  function depositERC1155(
    uint256 owningTokenId,
    address asset,
    uint256 id,
    uint256 amount
  ) public override nonReentrant onlyIfOwningTokenNotApproved(owningTokenId) {
    _depositERC1155(owningTokenId, asset, id, amount);
  }

  function _depositERC721(uint256 owningTokenId, address asset, uint256 id) internal {
    _validateAndEmitEvent(owningTokenId, asset, id, 1);
    // the following reverts if not an ERC721. We do not pre-check to save gas.
    IERC721Upgradeable(asset).safeTransferFrom(_msgSender(), address(this), id);
  }

  function _depositERC20(uint256 owningTokenId, address asset, uint256 amount) internal {
    _validateAndEmitEvent(owningTokenId, asset, 0, amount);
    // the following reverts if not an ERC20
    bool transferred = IERC20Upgradeable(asset).transferFrom(_msgSender(), address(this), amount);
    if (!transferred) revert TransferFailed();
  }

  function _depositERC1155(uint256 owningTokenId, address asset, uint256 id, uint256 amount) internal {
    _validateAndEmitEvent(owningTokenId, asset, id, amount);
    // the following reverts if not an ERC1155
    IERC1155Upgradeable(asset).safeTransferFrom(_msgSender(), address(this), id, amount, "");
  }

  function depositAssets(
    uint256 owningTokenId,
    address[] memory assets,
    uint256[] memory ids,
    uint256[] memory amounts
  ) external override nonReentrant onlyIfOwningTokenNotApproved(owningTokenId) {
    if (assets.length != ids.length || assets.length != amounts.length) revert InconsistentLengths();
    for (uint256 i = 0; i < assets.length; i++) {
      if (isERC20(assets[i])) {
        _depositERC20(owningTokenId, assets[i], amounts[i]);
      } else if (isERC721(assets[i])) {
        _depositERC721(owningTokenId, assets[i], ids[i]);
      } else if (isERC1155(assets[i])) {
        _depositERC1155(owningTokenId, assets[i], ids[i], amounts[i]);
      } else revert InvalidAsset();
    }
  }

  function _unconfirmedDepositExpired(uint256 timestamp) internal view returns (bool) {
    return timestamp + 1 weeks < block.timestamp;
  }

  function _owningTokenExists(uint256 owningTokenId) internal view returns (bool) {
    try _owningToken.ownerOf(owningTokenId) returns (address) {
      return true;
    } catch {}
    return false;
  }

  function confirmDeposit(
    uint256 owningTokenId,
    address asset,
    uint256 id,
    uint256 amount,
    address sender
  ) external override onlyOwningTokenOwner(owningTokenId) onlyIfOwningTokenNotApproved(owningTokenId) {
    bytes32 key = keccak256(abi.encodePacked(owningTokenId, asset, id, amount, sender));
    uint256 timestamp = _unconfirmedDeposits[key];
    if (timestamp == 0 || _unconfirmedDepositExpired(timestamp)) revert UnconfirmedDepositNotFoundOrExpired();
    _addAmountToDeposit(owningTokenId, asset, id, amount);
    emit Deposit(owningTokenId, asset, id, amount);
    delete _unconfirmedDeposits[key];
  }

  function withdrawExpiredUnconfirmedDeposit(
    uint256 owningTokenId,
    address asset,
    uint256 id,
    uint256 amount
  ) external override nonReentrant {
    bytes32 key = keccak256(abi.encodePacked(owningTokenId, asset, id, amount, _msgSender()));
    uint256 timestamp = _unconfirmedDeposits[key];
    if (timestamp == 0) revert UnconfirmedDepositNotFoundOrExpired();
    if (!_unconfirmedDepositExpired(timestamp)) revert UnconfirmedDepositNotExpiredYet();
    delete _unconfirmedDeposits[key];
    _transferToken(address(this), _msgSender(), asset, id, amount);
  }

  function _checkIfCanTransfer(
    uint256 owningTokenId,
    address asset,
    uint256 id,
    uint256 amount
  ) internal view virtual returns (bytes32) {
    if (amount == 0) revert InvalidAmount();
    bytes32 key = keccak256(abi.encodePacked(owningTokenId, asset, id));
    if (_depositAmounts[key] < amount) revert InsufficientBalance();
    return key;
  }

  function _transferAsset(
    uint256 owningTokenId,
    uint256 recipientOwningTokenId,
    address asset,
    uint256 id,
    uint256 amount
  ) internal virtual {
    bytes32 key = _checkIfCanTransfer(owningTokenId, asset, id, amount);
    if (recipientOwningTokenId > 0) {
      if (!_owningTokenExists(recipientOwningTokenId)) revert InvalidRecipient();
      _depositAmounts[keccak256(abi.encodePacked(recipientOwningTokenId, asset, id))] += amount;
    } // else the tokens is trashed
    if (_depositAmounts[key] - amount > 0) {
      _depositAmounts[key] -= amount;
    } else {
      delete _depositAmounts[key];
    }
    emit DepositTransfer(recipientOwningTokenId, asset, id, amount, owningTokenId);
  }

  function _checkIfStartAllowed(uint256 owningTokenId) internal view {
    if (_owningTokenIsProtected && IProtectedERC721(address(_owningToken)).hasProtector(ownerOf(owningTokenId)))
      revert NotAllowedWhenProtector();
  }

  // transfer asset to another owningToken
  function transferAsset(
    uint256 owningTokenId,
    uint256 recipientOwningTokenId,
    address asset,
    uint256 id,
    uint256 amount
  ) external override onlyOwningTokenOwner(owningTokenId) onlyIfOwningTokenNotApproved(owningTokenId) {
    if (ownerOf(owningTokenId) != ownerOf(recipientOwningTokenId)) {
      _checkIfStartAllowed(owningTokenId);
    }
    _checkIfChangeAllowed(owningTokenId);
    if (isERC721(asset)) {
      amount = 1;
    } else if (isERC20(asset)) {
      id = 0;
    }
    _transferAsset(owningTokenId, recipientOwningTokenId, asset, id, amount);
  }

  function startTransferAsset(
    uint256 owningTokenId,
    uint256 recipientOwningTokenId,
    address asset,
    uint256 id,
    uint256 amount,
    uint32 validFor
  ) external override onlyProtector(owningTokenId) onlyIfOwningTokenNotApproved(owningTokenId) {
    _checkIfCanTransfer(owningTokenId, asset, id, amount);
    bytes32 key = keccak256(abi.encodePacked(owningTokenId, recipientOwningTokenId, asset, id, amount));
    if (_restrictedTransfers[key].protector != address(0) || _restrictedTransfers[key].expiresAt > block.timestamp)
      revert AssetAlreadyBeingTransferred();
    _restrictedTransfers[
      keccak256(abi.encodePacked(owningTokenId, recipientOwningTokenId, asset, id, amount))
    ] = ProtectorAndTimestamp({protector: _msgSender(), expiresAt: uint32(block.timestamp) + validFor});
    emit DepositTransferStarted(recipientOwningTokenId, asset, id, amount, owningTokenId);
  }

  function _checkIfChangeAllowed(uint256 owningTokenId) internal view {
    if (_owningToken.getApproved(owningTokenId) != address(0)) revert ForbiddenWhenOwningTokenApprovedForSale();
  }

  function completeTransferAsset(
    uint256 owningTokenId,
    uint256 recipientOwningTokenId,
    address asset,
    uint256 id,
    uint256 amount
  ) external override onlyOwningTokenOwner(owningTokenId) onlyIfOwningTokenNotApproved(owningTokenId) {
    // we repeat the check because the user can try starting many transfers with different amounts
    _checkIfCanTransfer(owningTokenId, asset, id, amount);
    bytes32 key = keccak256(abi.encodePacked(owningTokenId, recipientOwningTokenId, asset, id, amount));
    if (
      _restrictedTransfers[key].protector != IProtectedERC721(address(_owningToken)).protectorFor(ownerOf(owningTokenId)) ||
      _restrictedTransfers[key].expiresAt < block.timestamp
    ) revert InvalidTransfer();
    _transferAsset(owningTokenId, recipientOwningTokenId, asset, id, amount);
    delete _restrictedTransfers[key];
  }

  function _transferToken(address from, address to, address asset, uint256 id, uint256 amount) internal {
    if (isERC721(asset)) {
      IERC721Upgradeable(asset).safeTransferFrom(from, to, id);
    } else if (isERC1155(asset)) {
      IERC1155Upgradeable(asset).safeTransferFrom(from, to, id, amount, "");
    } else if (isERC20(asset)) {
      bool transferred = IERC20Upgradeable(asset).transfer(to, amount);
      if (!transferred) revert TransferFailed();
    } else {
      // should never happen
      revert InvalidAsset();
    }
  }

  function _withdrawAsset(
    uint256 owningTokenId,
    address beneficiary,
    address asset,
    uint256 id,
    uint256 amount
  ) internal virtual {
    _checkIfChangeAllowed(owningTokenId);
    bytes32 key = _checkIfCanTransfer(owningTokenId, asset, id, amount);
    _transferToken(address(this), beneficiary, asset, id, amount);
    if (_depositAmounts[key] - amount > 0) {
      _depositAmounts[key] -= amount;
    } else {
      delete _depositAmounts[key];
    }
    emit Withdrawal(owningTokenId, beneficiary, asset, id, amount);
  }

  function withdrawAsset(
    uint256 owningTokenId,
    address asset,
    uint256 id,
    uint256 amount,
    address beneficiary
  ) external override onlyOwningTokenOwner(owningTokenId) nonReentrant {
    _checkIfStartAllowed(owningTokenId);
    _withdrawAsset(owningTokenId, beneficiary != address(0) ? beneficiary : _msgSender(), asset, id, amount);
  }

  function startWithdrawal(
    uint256 owningTokenId,
    address asset,
    uint256 id,
    uint256 amount,
    uint32 validFor,
    address beneficiary
  ) external override onlyProtector(owningTokenId) onlyIfOwningTokenNotApproved(owningTokenId) {
    _checkIfCanTransfer(owningTokenId, asset, id, amount);
    bytes32 key = keccak256(abi.encodePacked(owningTokenId, beneficiary, asset, id, amount));
    if (_restrictedWithdrawals[key].protector != address(0) && _restrictedWithdrawals[key].expiresAt > block.timestamp)
      revert AssetAlreadyBeingWithdrawn();
    _restrictedWithdrawals[key] = ProtectorAndTimestamp({
      protector: _msgSender(),
      expiresAt: uint32(block.timestamp) + validFor
    });
    emit WithdrawalStarted(owningTokenId, beneficiary, asset, id, amount);
  }

  function completeWithdrawal(
    uint256 owningTokenId,
    address asset,
    uint256 id,
    uint256 amount,
    address beneficiary
  ) external override onlyOwningTokenOwner(owningTokenId) nonReentrant onlyIfOwningTokenNotApproved(owningTokenId) {
    bytes32 key = keccak256(abi.encodePacked(owningTokenId, beneficiary, asset, id, amount));
    if (_restrictedWithdrawals[key].protector == address(0)) revert WithdrawalNotFound();
    if (_restrictedWithdrawals[key].expiresAt < block.timestamp) revert Expired();
    delete _restrictedWithdrawals[key];
    _withdrawAsset(owningTokenId, beneficiary, asset, id, amount);
  }

  // External services who need to see what a transparent vault contains can call
  // the Cruna Web API to get the list of assets owned by a owningToken. Then, they can call
  // this view to validate the results.
  function amountOf(
    uint256 owningTokenId,
    address[] memory asset,
    uint256[] memory id
  ) external view virtual override returns (uint256[] memory) {
    uint256[] memory amounts = new uint256[](asset.length);
    for (uint256 i = 0; i < asset.length; i++) {
      amounts[i] = _depositAmounts[keccak256(abi.encodePacked(owningTokenId, asset[i], id[i]))];
    }
    return amounts;
  }

  uint256[50] private __gap;
}
