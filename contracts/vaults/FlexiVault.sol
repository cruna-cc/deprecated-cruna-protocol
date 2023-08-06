// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol" as Ownable;
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC4906} from "../utils/IERC4906.sol";

import {ProtectedERC721, Strings} from "../protected/ProtectedERC721.sol";
import {FlexiVaultManager} from "../vaults/FlexiVaultManager.sol";
import {IFlexiVault} from "./IFlexiVault.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";

// reference implementation of a Cruna Vault
contract FlexiVault is IFlexiVault, IERC4906, ProtectedERC721 {
  using Strings for uint256;
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIdCounter;

  event TokenURIFrozen();
  event TokenURIUpdated(string uri);
  error FrozenTokenURI();
  error NotAMinter();
  error ZeroAddress();
  error CapReached();
  error VaultAlreadySet();

  string private _baseTokenURI;
  bool private _baseTokenURIFrozen;
  FlexiVaultManager public vaultManager;
  address public factoryAddress;

  constructor(
    string memory baseUri_,
    address tokenUtils,
    address actorsManager
  ) ProtectedERC721("Cruna Flexi Vault V1", "CRUNA", tokenUtils, actorsManager) {
    _baseTokenURI = baseUri_;
  }

  function supportsInterface(bytes4 interfaceId) public view virtual override(ProtectedERC721) returns (bool) {
    return interfaceId == type(IERC4906).interfaceId || super.supportsInterface(interfaceId);
  }

  function initVault(address flexiVaultManager) external override onlyOwner {
    if (address(vaultManager) != address(0)) revert VaultAlreadySet();
    if (FlexiVaultManager(flexiVaultManager).isFlexiVaultManager() != FlexiVaultManager.isFlexiVaultManager.selector)
      revert NotTheVaultManager();
    vaultManager = FlexiVaultManager(flexiVaultManager);
  }

  // set factory to 0x0 to disable a factory
  function setFactory(address factory) external onlyOwner {
    if (factory == address(0)) revert ZeroAddress();
    factoryAddress = factory;
  }

  function version() external pure returns (string memory) {
    return "1.0.0";
  }

  function setSignatureAsUsed(bytes calldata signature) public override {
    if (_msgSender() != address(vaultManager)) revert NotTheVaultManager();
    actorsManager.setSignatureAsUsed(signature);
  }

  function _cleanOperators(uint256 tokenId) internal override {
    vaultManager.removeOperatorsFor(tokenId);
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return _baseTokenURI;
  }

  function updateTokenURI(string memory uri) external override onlyOwner {
    if (_baseTokenURIFrozen) {
      revert FrozenTokenURI();
    }
    // after revealing, this allows to set up a final uri
    _baseTokenURI = uri;
    emit TokenURIUpdated(uri);
  }

  function freezeTokenURI() external override onlyOwner {
    _baseTokenURIFrozen = true;
    emit TokenURIFrozen();
  }

  function contractURI() public view override returns (string memory) {
    return string(abi.encodePacked(_baseTokenURI, "info"));
  }

  function safeMint(address to) public {
    if (_msgSender() != factoryAddress) revert NotAMinter();
    _mintNow(to);
  }

  function _mintNow(address to) internal {
    _tokenIdCounter.increment();
    uint tokenId = _tokenIdCounter.current();
    if (tokenId > vaultManager.maxTokenId()) revert CapReached();
    _safeMint(to, tokenId);
  }
}
