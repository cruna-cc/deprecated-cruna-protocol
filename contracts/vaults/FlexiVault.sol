// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Author: Francesco Sullo <francesco@sullo.co>

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../nft-owned/NFTOwned.sol";
import "../protected-nft/IProtectedERC721.sol";
import "../utils/ITokenUtils.sol";
import "../bound-account/IERC6551Account.sol";
import "../bound-account/IERC6551Registry.sol";
import "../bound-account/IERC6551Account.sol";
import "../bound-account/TrusteeNFT.sol";
import "../utils/IVersioned.sol";
import "./IFlexiVaultExtended.sol";

//import "hardhat/console.sol";

contract FlexiVault is IFlexiVaultExtended, IVersioned, Ownable, NFTOwned, ReentrancyGuard {
  mapping(bytes32 => uint256) private _unconfirmedDeposits;

  // modifiers

  mapping(uint => bool) private _ejects;

  IERC6551Registry internal _registry;
  IERC6551Account public boundAccount;
  IERC6551Account public boundAccountUpgradeable;
  ITokenUtils internal _tokenUtils;
  TrusteeNFT public trustee;
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
    _salt = uint(keccak256(abi.encodePacked(address(this), block.chainid, address(owningToken))));
    _tokenUtils = ITokenUtils(tokenUtils);
    if (_tokenUtils.isTokenUtils() != ITokenUtils.isTokenUtils.selector) revert InvalidTokenUtils();
  }

  /**
   * @dev {See IVersioned-version}
   */
  function version() external pure override returns (string memory) {
    return "1.0.0";
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
  function accountAddress(uint owningTokenId) external view override returns (address) {
    return _accountAddresses[owningTokenId];
  }

  /**
   * @dev {See IFlexiVault-activateAccount}
   */
  function activateAccount(uint owningTokenId, bool useUpgradeableAccount) external onlyOwningTokenOwner(owningTokenId) {
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

  /**
   * @dev {See IFlexiVault-depositAssets}
   */
  function depositAssets(
    uint256 owningTokenId,
    TokenType[] memory tokenTypes,
    address[] memory assets,
    uint256[] memory ids,
    uint256[] memory amounts
  ) external payable override nonReentrant onlyIfActiveAndOwningTokenNotApproved(owningTokenId) {
    if (assets.length != ids.length || assets.length != amounts.length || assets.length != tokenTypes.length)
      revert InconsistentLengths();
    for (uint256 i = 0; i < assets.length; i++) {
      if (tokenTypes[i] == TokenType.ETH) {
        if (msg.value == 0) revert NoETH();
        (bool success, ) = payable(_accountAddresses[owningTokenId]).call{value: msg.value}("");
        if (!success) revert ETHDepositFailed();
      } else if (tokenTypes[i] == TokenType.ERC20) {
        bool transferred = IERC20(assets[i]).transferFrom(_msgSender(), _accountAddresses[owningTokenId], amounts[i]);
        if (!transferred) revert TransferFailed();
      } else if (tokenTypes[i] == TokenType.ERC721) {
        IERC721(assets[i]).safeTransferFrom(_msgSender(), _accountAddresses[owningTokenId], ids[i]);
      } else if (tokenTypes[i] == TokenType.ERC1155) {
        IERC1155(assets[i]).safeTransferFrom(_msgSender(), _accountAddresses[owningTokenId], ids[i], amounts[i], "");
      } else revert InvalidAsset();
    }
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
    uint owningTokenId,
    TokenType tokenType,
    address to,
    address asset,
    uint256 id,
    uint256 amount
  ) internal {
    address walletAddress = _accountAddresses[owningTokenId];
    IERC6551Account accountInstance = IERC6551Account(payable(walletAddress));
    if (tokenType == TokenType.ETH) {
      // we talk of ETH
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
      // should never happen
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
    uint balance = _getAccountBalance(owningTokenId, asset, id);
    if (balance < amount) revert InsufficientBalance();
    _transferToken(owningTokenId, tokenType, beneficiary != address(0) ? beneficiary : _msgSender(), asset, id, amount);
  }

  /**
   * @dev {See IFlexiVault-withdrawAssets}
   */
  function withdrawAssets(
    uint owningTokenId,
    TokenType[] memory tokenTypes,
    address[] memory assets,
    uint256[] memory ids,
    uint256[] memory amounts,
    address[] memory beneficiaries
  )
    external
    override
    onlyOwningTokenOwnerOrOperator(owningTokenId)
    onlyIfActiveAndOwningTokenNotApproved(owningTokenId)
    nonReentrant
  {
    _isChangeAllowed(owningTokenId);
    if (assets.length != ids.length || assets.length != amounts.length) revert InconsistentLengths();
    for (uint256 i = 0; i < assets.length; i++) {
      _withdrawAsset(owningTokenId, tokenTypes[i], assets[i], ids[i], amounts[i], beneficiaries[i]);
    }
  }

  /**
   * @dev {See IFlexiVault-protectedWithdrawAssets}
   */
  function protectedWithdrawAssets(
    uint256 owningTokenId,
    TokenType[] memory tokenTypes,
    address[] memory assets,
    uint256[] memory ids,
    uint256[] memory amounts,
    address[] memory beneficiaries,
    uint256 timestamp,
    uint validFor,
    bytes calldata signature
  )
    external
    override
    onlyOwningTokenOwnerOrOperator(owningTokenId)
    onlyIfActiveAndOwningTokenNotApproved(owningTokenId)
    nonReentrant
  {
    if (assets.length != ids.length || assets.length != amounts.length || assets.length != beneficiaries.length)
      revert InconsistentLengths();
    bytes32 hash = _tokenUtils.hashWithdrawsRequest(
      owningTokenId,
      tokenTypes,
      assets,
      ids,
      amounts,
      beneficiaries,
      timestamp,
      validFor
    );
    _protectedOwningToken.validateTimestampAndSignature(owningTokenId, timestamp, validFor, hash, signature);
    for (uint256 i = 0; i < assets.length; i++) {
      _withdrawAsset(owningTokenId, tokenTypes[i], assets[i], ids[i], amounts[i], beneficiaries[i]);
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
    _isChangeAllowed(owningTokenId);
    _ejectAccount(owningTokenId);
  }

  /**
   * @dev {See IFlexiVault-protectedEjectAccount}
   */
  function protectedEjectAccount(
    uint256 owningTokenId,
    uint256 timestamp,
    uint validFor,
    bytes calldata signature
  ) external override {
    bytes32 hash = _tokenUtils.hashEjectRequest(owningTokenId, timestamp, validFor);
    _protectedOwningToken.validateTimestampAndSignature(owningTokenId, timestamp, validFor, hash, signature);
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

  uint256[50] private __gap;
}
