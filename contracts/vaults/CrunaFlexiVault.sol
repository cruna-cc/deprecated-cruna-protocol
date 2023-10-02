// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC4906} from "../utils/IERC4906.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {ProtectedERC721, Strings} from "../protected/ProtectedERC721.sol";
import {IFlexiVaultManager, FlexiVaultManager} from "../vaults/FlexiVaultManager.sol";
import {IFlexiVault} from "./IFlexiVault.sol";
import {CrunaWallet} from "./CrunaWallet.sol";

//import "hardhat/console.sol";

// reference implementation of a Cruna Vault
contract CrunaFlexiVault is IFlexiVault, IERC4906, ProtectedERC721, ReentrancyGuard {
  using Strings for uint256;

  event TokenURIFrozen();
  event TokenURIUpdated(string uri);
  error FrozenTokenURI();
  error NotAMinter();
  error ZeroAddress();
  error CapReached();
  error VaultManagerAlreadySet();
  error VaultManagerNotInitiated();
  error NotImplemented();
  error ForbiddenWhenTokenApprovedForSale();
  error TheAccountIsNotOwnedByTheFlexiVault();
  error AccountAlreadyEjected();
  error NotAllowedWhenProtector();
  error NotAPreviouslyEjectedAccount();
  error NotActivated();
  error TokenIdDoesNotExist();

  FlexiVaultManager public vaultManager;
  address public factoryAddress;

  uint public nextTokenId;
  uint public lastTokenId;
  CrunaWallet public wallet;

  modifier onlyIfActive(uint256 tokenId) {
    // It will revert if wallet not set, i.e., it the cruna vault has not been initiated
    if (wallet.ownerOf(tokenId) != address(vaultManager)) revert NotActivated();
    _;
  }

  modifier onlyIfNotApproved(uint256 tokenId) {
    // if the owningToken is approved for sale, the vaults cannot be modified to avoid scams
    if (getApproved(tokenId) != address(0)) revert ForbiddenWhenTokenApprovedForSale();
    _;
  }

  constructor(
    address actorsManager,
    address signatureValidator
  ) ProtectedERC721("Cruna Flexi Vault V1", "CRUNA_FV1", actorsManager, signatureValidator) {}

  function supportsInterface(bytes4 interfaceId) public view virtual override(ProtectedERC721) returns (bool) {
    return interfaceId == type(IERC4906).interfaceId || super.supportsInterface(interfaceId);
  }

  function initVault(address flexiVaultManager) public virtual override onlyOwner {
    // must be called after than the vaultManager has been initiated
    if (address(vaultManager) != address(0)) revert VaultManagerAlreadySet();
    if (FlexiVaultManager(flexiVaultManager).isFlexiVaultManager() != FlexiVaultManager.isFlexiVaultManager.selector)
      revert NotTheVaultManager();
    vaultManager = FlexiVaultManager(flexiVaultManager);
    wallet = CrunaWallet(vaultManager.wallet());
    if (address(wallet) == address(0)) revert VaultManagerNotInitiated();
    nextTokenId = wallet.firstTokenId();
    lastTokenId = wallet.lastTokenId();
  }

  // set factory to 0x0 to disable a factory
  function setFactory(address factory) external virtual override onlyOwner {
    if (factory == address(0)) revert ZeroAddress();
    factoryAddress = factory;
  }

  function version() external pure virtual returns (string memory) {
    return "1.0.0";
  }

  function setSignatureAsUsed(bytes calldata signature) public virtual override {
    if (_msgSender() != address(vaultManager)) revert NotTheVaultManager();
    actorsManager.setSignatureAsUsed(signature);
  }

  function _cleanOperators(uint256 tokenId) internal override {
    vaultManager.removeOperatorsFor(tokenId);
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return "https://meta.cruna.cc/flexy-vault/v1/";
  }

  function contractURI() public view virtual returns (string memory) {
    return "https://meta.cruna.cc/flexy-vault/v1/info";
  }

  function safeMint(address to) public virtual override {
    if (_msgSender() != factoryAddress) revert NotAMinter();
    _mintNow(to);
  }

  function mintFromCrunaWallet(uint) external virtual override {
    revert NotImplemented(); // not enabled in version 1
  }

  function _mintNow(address to) internal {
    if (lastTokenId == 0) revert VaultManagerNotInitiated();
    if (nextTokenId > lastTokenId) revert CapReached();
    _safeMint(to, nextTokenId++);
  }

  /**
   * @dev {See FlexiVaultManager.sol-ejectAccount}
   */
  function ejectAccount(
    uint256 tokenId,
    uint256 timestamp,
    uint256 validFor,
    bytes calldata signature
  ) external virtual override onlyTokenOwner(tokenId) nonReentrant {
    if (!_exists(tokenId)) revert TokenIdDoesNotExist();
    if (wallet.ownerOf(tokenId) != address(vaultManager)) revert AccountAlreadyEjected();
    if (getApproved(tokenId) != address(0)) revert ForbiddenWhenTokenApprovedForSale();
    if (timestamp != 0) {
      actorsManager.checkIfSignatureUsed(signature);
      actorsManager.isNotExpired(timestamp, validFor);
      address signer = signatureValidator.signEjectRequest(tokenId, timestamp, validFor, signature);
      actorsManager.isSignerAProtector(ownerOf(tokenId), signer);
    } else if (actorsManager.hasProtectors(ownerOf(tokenId)).length > 0) revert NotAllowedWhenProtector();
    vaultManager.ejectAccount(tokenId);
  }

  /**
   * @dev {See FlexiVaultManager.sol-injectEjectedAccount}
   */
  function injectEjectedAccount(uint256 tokenId) external virtual override onlyTokenOwner(tokenId) nonReentrant {
    if (!_exists(tokenId)) revert TokenIdDoesNotExist();
    // it reverts if called before initiating the vault, or with non-existing token
    if (wallet.ownerOf(tokenId) != address(vaultManager)) {
      // the contract must be approved
      wallet.transferFrom(_msgSender(), address(vaultManager), tokenId);
    }
    vaultManager.injectEjectedAccount(tokenId);
  }

  // Activation

  function activateAccount(uint256 tokenId) external virtual override onlyTokenOwner(tokenId) {
    vaultManager.activateAccount(tokenId);
  }

  // deposits

  function depositAssets(
    uint256 tokenId,
    IFlexiVaultManager.TokenType[] memory tokenTypes,
    address[] memory assets,
    uint256[] memory ids,
    uint256[] memory amounts
  ) external payable nonReentrant onlyIfActive(tokenId) {
    vaultManager.depositAssets{value: msg.value}(tokenId, tokenTypes, assets, ids, amounts, _msgSender());
  }

  function withdrawAssets(
    uint256 tokenId,
    IFlexiVaultManager.TokenType[] memory tokenTypes,
    address[] memory assets,
    uint256[] memory ids,
    uint256[] memory amounts,
    address[] memory recipients,
    uint256 timestamp,
    uint256 validFor,
    bytes calldata signature
  ) external override onlyIfActive(tokenId) onlyIfNotApproved(tokenId) nonReentrant {
    vaultManager.withdrawAssets(
      tokenId,
      tokenTypes,
      assets,
      ids,
      amounts,
      recipients,
      timestamp,
      validFor,
      signature,
      _msgSender()
    );
  }
}
