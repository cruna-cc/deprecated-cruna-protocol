// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Author: Francesco Sullo <francesco@sullo.co>

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../nft-owned/NFTOwned.sol";
import "../protected-nft/IProtectedERC721.sol";
import "../utils/TokenUtils.sol";
import "../bound-account/ERC6551Account.sol";
import "../bound-account/IERC6551Registry.sol";
import "../bound-account/IERC6551Account.sol";
import "../bound-account/OwnerNFT.sol";

import "./ITransparentVault.sol";

//import "hardhat/console.sol";

contract TransparentVault is ITransparentVault, Ownable, NFTOwned, ReentrancyGuard, TokenUtils {
  mapping(bytes32 => uint256) private _unconfirmedDeposits;

  // modifiers

  mapping(uint => bool) private _ejects;

  bool internal _owningTokenIsProtected;
  IERC6551Registry internal _registry;
  ERC6551Account internal _account;
  OwnerNFT public ownerNFT;
  uint internal _salt;
  mapping(uint => address) internal _accountAddresses;
  bool private _initiated;
  IProtectedERC721 internal _protectedOwningToken;

  modifier onlyOwningTokenOwner(uint256 owningTokenId) {
    if (ownerOf(owningTokenId) != msg.sender) {
      revert NotTheOwningTokenOwner();
    }
    _;
  }

  modifier onlyOwningTokenOwnerOrOperator(uint256 owningTokenId) {
    if (!_protectedOwningToken.isOwnerOrOperator(owningTokenId, _msgSender())) {
      revert NotTheOwningTokenOwnerOrOperatorFor();
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
    // if the owningToken is approved for sale, the vaults cannot be modified to avoid scams
    if (_owningToken.getApproved(owningTokenId) != address(0)) revert ForbiddenWhenOwningTokenApprovedForSale();
    _;
  }

  // solhint-disable-next-line
  constructor(address owningToken) NFTOwned(owningToken) {
    _protectedOwningToken = IProtectedERC721(owningToken);
    if (IERC165(_owningToken).supportsInterface(type(IProtectedERC721).interfaceId)) {
      _owningTokenIsProtected = true;
    }
    _salt = uint(keccak256(abi.encodePacked(address(this), block.chainid, address(owningToken))));
  }

  /*
    @dev It allows to set the registry and the account proxy
    @param registry The address of the registry
    @param proxy The address of the account proxy
  */
  function init(address registry, address payable account) external override onlyOwner {
    if (_initiated) revert AlreadyInitiated();
    if (!IERC165(registry).supportsInterface(type(IERC6551Registry).interfaceId)) revert InvalidRegistry();
    _registry = IERC6551Registry(registry);
    if (!IERC165(account).supportsInterface(type(IERC6551Account).interfaceId)) revert InvalidAccount();
    _account = ERC6551Account(account);
    ownerNFT = new OwnerNFT();
    ownerNFT.setMinter(address(this), true);
    ownerNFT.transferOwnership(_msgSender());
    _initiated = true;
  }

  function isTransparentVault() external pure override returns (bytes4) {
    return this.isTransparentVault.selector;
  }

  function accountAddress(uint owningTokenId) public view returns (address) {
    return _registry.account(address(_account), block.chainid, address(ownerNFT), owningTokenId, _salt);
  }

  function activateAccount(uint owningTokenId) external onlyOwningTokenOwner(owningTokenId) {
    address account = accountAddress(owningTokenId);
    ownerNFT.mint(address(this), owningTokenId);
    if (_accountAddresses[owningTokenId] != address(0)) revert AccountAlreadyActive();
    _accountAddresses[owningTokenId] = account;
    _registry.createAccount(address(_account), block.chainid, address(ownerNFT), owningTokenId, _salt, "");
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
  ) public override onlyOwningTokenOwnerOrOperator(owningTokenId) nonReentrant {
    _checkIfStartAllowed(owningTokenId);
    _withdrawAsset(owningTokenId, beneficiary != address(0) ? beneficiary : _msgSender(), asset, id, amount);
  }

  function withdrawAsset(uint256 owningTokenId, address asset, uint256 id, uint256 amount, uint recipientTokenId) external {
    withdrawAsset(owningTokenId, asset, id, amount, accountAddress(recipientTokenId));
  }

  function protectedWithdrawAsset(
    uint256 owningTokenId,
    address asset,
    uint256 id,
    uint256 amount,
    address beneficiary,
    uint256 timestamp,
    uint randomSalt,
    bytes calldata signature,
    bool invalidateSignatureAfterUse
  ) public override onlyOwningTokenOwnerOrOperator(owningTokenId) nonReentrant {
    if (timestamp > block.timestamp || timestamp < block.timestamp - 1 days) revert TimestampInvalidOrExpired();
    bytes32 hash = hashWithdrawRequest(owningTokenId, asset, id, amount, beneficiary, timestamp, randomSalt);
    if (!_protectedOwningToken.signedByProtector(owningTokenId, hash, signature)) revert WrongDataOrNotSignedByProtector();
    if (_protectedOwningToken.isSignatureUsed(keccak256(signature))) revert SignatureAlreadyUsed();
    if (invalidateSignatureAfterUse) {
      _protectedOwningToken.setSignatureAsUsed(keccak256(signature));
    }
    _checkIfStartAllowed(owningTokenId);
    _withdrawAsset(owningTokenId, beneficiary != address(0) ? beneficiary : _msgSender(), asset, id, amount);
  }

  function protectedWithdrawAsset(
    uint256 owningTokenId,
    address asset, // if address(0) we want to withdraw the native token, for example Ether
    uint256 id,
    uint256 amount,
    uint recipientTokenId,
    uint256 timestamp,
    uint randomSalt,
    bytes calldata signature,
    bool invalidateSignatureAfterUse
  ) external {
    protectedWithdrawAsset(
      owningTokenId,
      asset,
      id,
      amount,
      accountAddress(recipientTokenId),
      timestamp,
      randomSalt,
      signature,
      invalidateSignatureAfterUse
    );
  }

  function hashWithdrawRequest(
    uint256 owningTokenId,
    address asset,
    uint256 id,
    uint256 amount,
    address beneficiary,
    uint256 timestamp,
    uint randomSalt
  ) public view override returns (bytes32) {
    return
      keccak256(
        abi.encodePacked("\x19\x01", block.chainid, owningTokenId, asset, id, amount, beneficiary, timestamp, randomSalt)
      );
  }

  // External services who need to see what a transparent vaults contains can call
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
