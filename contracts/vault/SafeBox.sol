// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Author: Francesco Sullo <francesco@sullo.co>

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../nft-owned/NFTOwned.sol";
import "../protected-nft/IProtectedERC721.sol";
import "../utils/TokenUtils.sol";
import "../bound-account/ERC6551AccountProxy.sol";
import "../bound-account/IERC6551Registry.sol";
import "../bound-account/IERC6551Account.sol";
import "../bound-account/OwnerNFT.sol";

import "./ISafeBox.sol";

import "hardhat/console.sol";

contract SafeBox is ISafeBox, Ownable, NFTOwned, ReentrancyGuard, TokenUtils {
  mapping(bytes32 => uint256) private _unconfirmedDeposits;

  mapping(bytes32 => ProtectorAndTimestamp) private _restrictedTransfers;

  mapping(bytes32 => ProtectorAndTimestamp) private _restrictedWithdrawals;
  // modifiers

  mapping(uint => bool) private _ejects;

  bool internal _owningTokenIsProtected;
  IERC6551Registry internal _registry;
  ERC6551AccountProxy internal _accountProxy;
  OwnerNFT public ownerNFT;
  uint internal _salt;
  mapping(uint => address) internal _accountAddresses;
  bool private _initiated;

  modifier onlyOwningTokenOwner(uint256 owningTokenId) {
    if (ownerOf(owningTokenId) != msg.sender) {
      revert NotTheOwningTokenOwner();
    }
    _;
  }

  modifier onlyProtector(uint256 owningTokenId) {
    if (
      !_owningTokenIsProtected || !IProtectedERC721(address(_owningToken)).isProtectorFor(ownerOf(owningTokenId), _msgSender())
    ) revert NotTheProtector();
    _;
  }

  modifier onlyIfActiveAndOwningTokenNotApproved(uint256 owningTokenId) {
    if (_ejects[owningTokenId]) {
      revert AccountHasBeenEjected();
    }
    if (_accountAddresses[owningTokenId] == address(0)) revert NotActivated();
    // if the owningToken is approved for sale, the vault cannot be modified to avoid scams
    if (_owningToken.getApproved(owningTokenId) != address(0)) revert ForbiddenWhenOwningTokenApprovedForSale();
    _;
  }

  // solhint-disable-next-line
  constructor(address owningToken) NFTOwned(owningToken) {
    if (IERC165(_owningToken).supportsInterface(type(IProtectedERC721).interfaceId)) {
      _owningTokenIsProtected = true;
    }
    _salt = uint(keccak256(abi.encodePacked(address(this), block.chainid, address(owningToken))));
  }

  function init(address registry, address payable proxy) external override onlyOwner {
    if (_initiated) revert AlreadyInitiated();
    if (!IERC165(registry).supportsInterface(type(IERC6551Registry).interfaceId)) revert InvalidRegistry();
    _registry = IERC6551Registry(registry);
    try ERC6551AccountProxy(proxy).isERC6551AccountProxy() returns (bool isProxy) {
      if (!isProxy) revert InvalidAccountProxy();
    } catch {
      revert InvalidAccountProxy();
    }
    _accountProxy = ERC6551AccountProxy(proxy);
    ownerNFT = new OwnerNFT();
    ownerNFT.setMinter(address(this), true);
    ownerNFT.transferOwnership(_msgSender());
    _initiated = true;
  }

  function isSafeBox() external pure override returns (bytes4) {
    return this.isSafeBox.selector;
  }

  function accountAddress(uint owningTokenId) public view returns (address) {
    return _registry.account(address(_accountProxy), block.chainid, address(ownerNFT), owningTokenId, _salt);
  }

  function activateAccount(uint owningTokenId) external onlyOwningTokenOwner(owningTokenId) {
    address account = accountAddress(owningTokenId);
    ownerNFT.mint(address(this), owningTokenId);
    if (_accountAddresses[owningTokenId] != address(0)) revert AccountAlreadyActive();
    _accountAddresses[owningTokenId] = account;
    _registry.createAccount(address(_accountProxy), block.chainid, address(ownerNFT), owningTokenId, _salt, "");
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
    IERC721(asset).safeTransferFrom(_msgSender(), _accountAddresses[owningTokenId], id);
  }

  function depositETH(uint256 owningTokenId) external payable override onlyIfActiveAndOwningTokenNotApproved(owningTokenId) {
    if (msg.value == 0) revert NoETH();
    emit Deposit(owningTokenId, address(0), 0, msg.value);
    (bool success, ) = payable(_accountAddresses[owningTokenId]).call{value: msg.value}("");
    if (!success) revert ETHDepositFailed();
  }

  function _depositERC20(uint256 owningTokenId, address asset, uint256 amount) internal {
    emit Deposit(owningTokenId, asset, 0, amount);
    // the following reverts if not an ERC20
    bool transferred = IERC20(asset).transferFrom(_msgSender(), _accountAddresses[owningTokenId], amount);
    if (!transferred) revert TransferFailed();
  }

  function _depositERC1155(uint256 owningTokenId, address asset, uint256 id, uint256 amount) internal {
    emit Deposit(owningTokenId, asset, id, amount);
    // the following reverts if not an ERC1155
    IERC1155(asset).safeTransferFrom(_msgSender(), _accountAddresses[owningTokenId], id, amount, "");
  }

  function depositAssets(
    uint256 owningTokenId,
    address[] memory assets,
    uint256[] memory ids, // 0 for ERC20
    uint256[] memory amounts // 1 for ERC721
  ) external override nonReentrant onlyIfActiveAndOwningTokenNotApproved(owningTokenId) {
    if (assets.length != ids.length || assets.length != amounts.length) revert InconsistentLengths();
    for (uint256 i = 0; i < assets.length; i++) {
      if (ids[i] == 0 && isERC20(assets[i])) {
        _depositERC20(owningTokenId, assets[i], amounts[i]);
      } else if (amounts[i] == 1 && isERC721(assets[i])) {
        _depositERC721(owningTokenId, assets[i], ids[i]);
      } else if (amounts[i] > 0 && isERC1155(assets[i])) {
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

  function _checkIfCanTransfer(uint256 owningTokenId, address asset, uint256 id, uint256 amount) internal view {
    if (amount == 0) revert InvalidAmount();
    uint balance = _getAccountBalance(owningTokenId, asset, id);
    if (balance < amount) revert InsufficientBalance();
  }

  function _getAccountBalance(uint256 owningTokenId, address asset, uint256 id) internal view returns (uint256) {
    address account = accountAddress(owningTokenId);
    if (asset == address(0)) {
      return account.balance;
    } else if (isERC20(asset)) {
      return IERC20(asset).balanceOf(account);
    } else if (isERC721(asset)) {
      return IERC721(asset).ownerOf(id) == account ? 1 : 0;
    } else if (isERC1155(asset)) {
      return IERC1155(asset).balanceOf(account, id);
    } else revert InvalidAsset();
  }

  function _checkIfStartAllowed(uint256 owningTokenId) internal view {
    if (_owningTokenIsProtected && IProtectedERC721(address(_owningToken)).protectorsFor(ownerOf(owningTokenId)).length > 0)
      revert NotAllowedWhenProtector();
  }

  function _checkIfChangeAllowed(uint256 owningTokenId) internal view {
    if (_owningToken.getApproved(owningTokenId) != address(0)) revert ForbiddenWhenOwningTokenApprovedForSale();
  }

  function _transferToken(uint owningTokenId, address to, address asset, uint256 id, uint256 amount) internal {
    address account = _accountAddresses[owningTokenId];
    IERC6551Account accountInstance = IERC6551Account(payable(account));
    if (asset == address(0)) {
      // we talk of ETH
      accountInstance.executeCall(account, amount, "");
    } else if (isERC721(asset)) {
      accountInstance.executeCall(
        asset,
        0,
        abi.encodeWithSignature("safeTransferFrom(address,address,uint256)", account, to, id)
      );
    } else if (isERC1155(asset)) {
      accountInstance.executeCall(
        asset,
        0,
        abi.encodeWithSignature("safeTransferFrom(address,address,uint256,uint256,bytes)", account, to, id, amount, "")
      );
    } else if (isERC20(asset)) {
      accountInstance.executeCall(asset, 0, abi.encodeWithSignature("transfer(address,uint256)", to, amount));
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
    _checkIfCanTransfer(owningTokenId, asset, id, amount);
    emit Withdrawal(owningTokenId, beneficiary, asset, id, amount);
    _transferToken(owningTokenId, beneficiary, asset, id, amount);
  }

  function withdrawAsset(
    uint256 owningTokenId,
    address asset, // if address(0) we want to withdraw the native token, for example Ether
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
      amounts[i] = _getAccountBalance(owningTokenId, asset[i], id[i]);
    }
    return amounts;
  }

  function ejectAccount(
    uint256 owningTokenId
  ) external onlyOwningTokenOwner(owningTokenId) onlyIfActiveAndOwningTokenNotApproved(owningTokenId) {
    if (_ejects[owningTokenId]) revert AccountAlreadyEjected();
    ownerNFT.safeTransferFrom(address(this), ownerOf(owningTokenId), owningTokenId);
    _ejects[owningTokenId] = true;
    emit BoundAccountEjected(owningTokenId);
  }

  function reInjectEjectedAccount(uint256 owningTokenId) external onlyOwningTokenOwner(owningTokenId) {
    if (!_ejects[owningTokenId]) revert NotAPreviouslyEjectedAccount();
    // the contract must be approved
    ownerNFT.transferFrom(ownerOf(owningTokenId), address(this), owningTokenId);
    delete _ejects[owningTokenId];
    emit EjectedBoundAccountReInjected(owningTokenId);
  }

  uint256[50] private __gap;
}
