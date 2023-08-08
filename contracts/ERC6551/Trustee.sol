// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IFlexiVaultManager} from "../vaults/IFlexiVaultManager.sol";

import {ITrustee} from "./ITrustee.sol";

// @dev The NFTs owning the bound account are all minted from this contract.
// The vaultManager must be an active FlexiVaultManager.sol
// The NFT can be ejected from the FlexiVaultManager.sol and transferred to the owner
contract Trustee is ITrustee, ERC721, Ownable {
  error TokenIdOutOfRange();
  error Forbidden();

  address public vaultManager;
  mapping(uint => address) private _boundAccounts;

  constructor() ERC721("Cruna Trustee", "CRUNA_T1") {
    vaultManager = msg.sender;
  }

  function version() external pure virtual returns (string memory) {
    return "1.0.0";
  }

  function mint(address to, uint256 tokenId) public virtual {
    if (msg.sender != vaultManager) revert Forbidden();
    if (tokenId < firstTokenId() || tokenId > lastTokenId()) revert TokenIdOutOfRange();
    _mint(to, tokenId);
  }

  function isTrustee() external pure virtual override returns (bytes4) {
    return ITrustee.isTrustee.selector;
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return "https://meta.cruna.io/trustee/v1/";
  }

  function contractURI() public view virtual returns (string memory) {
    return "https://meta.cruna.io/trustee/v1/info";
  }

  function firstTokenId() public pure virtual override returns (uint) {
    return 1;
  }

  function lastTokenId() public pure virtual override returns (uint) {
    return 100000;
  }

  function boundAccount(uint tokenId) external view virtual override returns (address) {
    return IFlexiVaultManager(vaultManager).accountAddress(tokenId);
  }
}
