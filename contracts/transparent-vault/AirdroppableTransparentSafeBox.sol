// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Author: Francesco Sullo <francesco@sullo.co>

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

import "../nft-owned/NFTOwnedUpgradeable.sol";
import "../protected-nft/IProtectedERC721.sol";
import "../utils/TokenUtils.sol";
import "../bound-account/ERC6551AccountProxy.sol";
import "../bound-account/IERC6551Registry.sol";
import "../bound-account/IERC6551Account.sol";
import "../utils/OwnerNFT.sol";

import "./IAirdroppableTransparentSafeBox.sol";

import "hardhat/console.sol";

// TODO this is a work-in-progress

contract AirdroppableTransparentSafeBox is
  IAirdroppableTransparentSafeBox,
  ContextUpgradeable,
  NFTOwnedUpgradeable,
  ReentrancyGuardUpgradeable,
  TokenUtils
{
  mapping(bytes32 => uint256) private _unconfirmedDeposits;

  mapping(bytes32 => ProtectorAndTimestamp) private _restrictedTransfers;

  mapping(bytes32 => ProtectorAndTimestamp) private _restrictedWithdrawals;
  // modifiers

  mapping(bytes32 => uint256) private _depositAmounts;

  bool internal _owningTokenIsProtected;
  IERC6551Registry internal _registry;
  ERC6551AccountProxy internal _accountProxy;
  OwnerNFT internal _ownerNFT;
  uint internal _salt;
  mapping(uint => address) internal _accountAddresses;

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

  modifier onlyIfActiveAndOwningTokenNotApproved(uint256 owningTokenId) {
    if (_accountAddresses[owningTokenId] == address(0)) revert NotActivated();
    // if the owningToken is approved for sale, the vault cannot be modified to avoid scams
    if (_owningToken.getApproved(owningTokenId) != address(0)) revert ForbiddenWhenOwningTokenApprovedForSale();
    _;
  }

  // solhint-disable-next-line
  function __AirdroppableTransparentSafeBox_init(
    address owningToken,
    address registry,
    address payable proxy
  ) internal onlyInitializing {
    __NFTOwned_init(owningToken);
    if (IERC165Upgradeable(_owningToken).supportsInterface(type(IProtectedERC721).interfaceId)) {
      _owningTokenIsProtected = true;
    }
    if (!IERC165Upgradeable(registry).supportsInterface(type(IERC6551Registry).interfaceId)) revert InvalidRegistry();
    _registry = IERC6551Registry(registry);
    try ERC6551AccountProxy(proxy).isERC6551AccountProxy() returns (bool isProxy) {
      if (!isProxy) revert InvalidAccountProxy();
    } catch {
      revert InvalidAccountProxy();
    }
    _accountProxy = ERC6551AccountProxy(proxy);
    __ReentrancyGuard_init();
    _ownerNFT = new OwnerNFT();
    _salt = uint(keccak256(abi.encodePacked(address(this), block.chainid, address(owningToken))));
  }

  function getAccountAddress(uint owningTokenId) public view returns (address) {
    return _registry.account(address(_accountProxy), block.chainid, address(owningToken()), owningTokenId, _salt);
  }

  function activateAccount(uint owningTokenId) external onlyOwningTokenOwner(owningTokenId) {
    address account = getAccountAddress(owningTokenId);
    if (_accountAddresses[owningTokenId] != address(0)) revert AccountAlreadyActive();
    //    IERC6551Account accountInstance = IERC6551Account(payable(account));
    //    try accountInstance.token() returns (uint256, address , uint256 tokenId_) {
    //      if (tokenId_ == owningTokenId) revert AccountAlreadyActive();
    //    } catch {}
    _accountAddresses[owningTokenId] = account;
    _registry.createAccount(address(_accountProxy), block.chainid, address(owningToken()), owningTokenId, _salt, "");
  }

  //  function _addAmountToDeposit(uint owningTokenId, address asset, uint id, uint amount) internal virtual {
  //    _depositAmounts[keccak256(abi.encodePacked(owningTokenId, asset, id))] += amount;
  //  }

  function _validateAndEmitEvent(uint256 owningTokenId, address asset, uint256 id, uint256 amount) internal {
    //    _addAmountToDeposit(owningTokenId, asset, id, amount);
    emit Deposit(owningTokenId, asset, id, amount);
  }

  function depositERC721(
    uint256 owningTokenId,
    address asset,
    uint256 id
  ) public override nonReentrant onlyIfActiveAndOwningTokenNotApproved(owningTokenId) {
    _depositERC721(owningTokenId, asset, id);
  }

  function depositERC20(
    uint256 owningTokenId,
    address asset,
    uint256 amount
  ) public override nonReentrant onlyIfActiveAndOwningTokenNotApproved(owningTokenId) {
    _depositERC20(owningTokenId, asset, amount);
  }

  function depositERC1155(
    uint256 owningTokenId,
    address asset,
    uint256 id,
    uint256 amount
  ) public override nonReentrant onlyIfActiveAndOwningTokenNotApproved(owningTokenId) {
    _depositERC1155(owningTokenId, asset, id, amount);
  }

  function _depositERC721(uint256 owningTokenId, address asset, uint256 id) internal {
    emit Deposit(owningTokenId, asset, id, 1);

    // the following reverts if not an ERC721. We do not pre-check to save gas.
    IERC721Upgradeable(asset).safeTransferFrom(_msgSender(), _accountAddresses[owningTokenId], id);
  }

  function depositETH(uint256 owningTokenId) external payable override onlyIfActiveAndOwningTokenNotApproved(owningTokenId) {
    if (msg.value == 0) revert NoETH();
    emit Deposit(owningTokenId, address(0), 0, msg.value);
    payable(_accountAddresses[owningTokenId]).transfer(msg.value);
  }

  function _depositERC20(uint256 owningTokenId, address asset, uint256 amount) internal {
    emit Deposit(owningTokenId, asset, 0, amount);
    // the following reverts if not an ERC20
    bool transferred = IERC20Upgradeable(asset).transferFrom(_msgSender(), _accountAddresses[owningTokenId], amount);
    if (!transferred) revert TransferFailed();
  }

  function _depositERC1155(uint256 owningTokenId, address asset, uint256 id, uint256 amount) internal {
    emit Deposit(owningTokenId, asset, id, amount);
    // the following reverts if not an ERC1155
    IERC1155Upgradeable(asset).safeTransferFrom(_msgSender(), _accountAddresses[owningTokenId], id, amount, "");
  }

  function depositAssets(
    uint256 owningTokenId,
    address[] memory assets,
    uint256[] memory ids,
    uint256[] memory amounts
  ) external override nonReentrant onlyIfActiveAndOwningTokenNotApproved(owningTokenId) {
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
  ) external override onlyOwningTokenOwner(owningTokenId) onlyIfActiveAndOwningTokenNotApproved(owningTokenId) {
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
  ) external override onlyProtector(owningTokenId) onlyIfActiveAndOwningTokenNotApproved(owningTokenId) {
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
  ) external override onlyOwningTokenOwner(owningTokenId) onlyIfActiveAndOwningTokenNotApproved(owningTokenId) {
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

  function _sendDepositedERC721(
    uint256 owningTokenId,
    address asset,
    uint256 id,
    address to
  ) internal returns (bytes memory _result) {
    address account = _accountAddresses[owningTokenId];
    IERC6551Account accountInstance = IERC6551Account(payable(account));
    return
      accountInstance.executeCall(
        address(account),
        0,
        abi.encodeWithSignature(
          "executeCall(address,uint256,bytes)",
          asset,
          0,
          abi.encodeWithSignature("safeTransferFrom(address,address,uint256)", address(account), to, id)
        )
      );
  }

  function _transferToken(uint owningTokenId, address to, address asset, uint256 id, uint256 amount) internal {
    address account = _accountAddresses[owningTokenId];
    IERC6551Account accountInstance = IERC6551Account(payable(account));
    if (asset == address(0)) {
      // we talk of ETH
      accountInstance.executeCall(address(account), amount, "");
    } else if (isERC721(asset)) {
      accountInstance.executeCall(
        address(account),
        0,
        abi.encodeWithSignature(
          "executeCall(address,uint256,bytes)",
          asset,
          0,
          abi.encodeWithSignature("safeTransferFrom(address,address,uint256)", address(account), to, id)
        )
      );
      //      IERC721Upgradeable(asset).safeTransferFrom(from, to, id);
    } else if (isERC1155(asset)) {
      //      IERC1155Upgradeable(asset).safeTransferFrom(from, to, id, amount, "");
      accountInstance.executeCall(
        address(account),
        0,
        abi.encodeWithSignature(
          "executeCall(address,uint256,bytes)",
          asset,
          0,
          abi.encodeWithSignature(
            "safeTransferFrom(address,address,uint256,uint256,bytes)",
            address(account),
            to,
            id,
            amount,
            ""
          )
        )
      );
    } else if (isERC20(asset)) {
      //      bool transferred = IERC20Upgradeable(asset).transfer(to, amount);
      //      if (!transferred) revert TransferFailed();
      accountInstance.executeCall(
        address(account),
        0,
        abi.encodeWithSignature(
          "executeCall(address,uint256,bytes)",
          asset,
          0,
          abi.encodeWithSignature("transfer(address,uint256)", to, amount)
        )
      );
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
    _transferToken(owningTokenId, beneficiary, asset, id, amount);
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
  ) external override onlyProtector(owningTokenId) onlyIfActiveAndOwningTokenNotApproved(owningTokenId) {
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
  ) external override onlyOwningTokenOwner(owningTokenId) nonReentrant onlyIfActiveAndOwningTokenNotApproved(owningTokenId) {
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
      if (address(asset[i]) == address(0)) {
        amounts[i] = _accountAddresses[owningTokenId].balance;
      } else if (isERC721(asset[i])) {
        amounts[i] = IERC721Upgradeable(asset[i]).balanceOf(_accountAddresses[owningTokenId]);
      } else if (isERC20(asset[i])) {
        amounts[i] = IERC20Upgradeable(asset[i]).balanceOf(_accountAddresses[owningTokenId]);
      } else if (isERC1155(asset[i])) {
        amounts[i] = IERC1155Upgradeable(asset[i]).balanceOf(_accountAddresses[owningTokenId], id[i]);
      } else {
        // should never happen
        revert InvalidAsset();
      }
    }
    return amounts;
  }

  uint256[50] private __gap;
}
