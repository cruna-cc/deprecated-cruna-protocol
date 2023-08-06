// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IFlexiVaultManager} from "../vaults/IFlexiVaultManager.sol";
import {ITrustee} from "./ITrustee.sol";

// @dev The NFTs owning the bound account are all minted from this contract.
// The minter must be an active FlexiVaultManager.sol
// The NFT can be ejected from the FlexiVaultManager.sol and transferred to the owner
contract Trustee is ITrustee, ERC721, Ownable {
  event MinterSet(address indexed minter, bool active);
  error NotAMinter();
  error MinterNotAFlexiVaultManager();

  mapping(address => bool) private _minters;

  constructor() ERC721("Trustee", "oNFT") {}

  // the minter must be an
  function setMinter(address minter, bool active) public onlyOwner {
    if (active) {
      try IFlexiVaultManager(minter).isFlexiVaultManager() returns (bytes4 result) {
        if (result != IFlexiVaultManager.isFlexiVaultManager.selector) revert MinterNotAFlexiVaultManager();
      } catch {
        revert MinterNotAFlexiVaultManager();
      }
      _minters[minter] = true;
    } else if (_minters[minter]) delete _minters[minter];
    emit MinterSet(minter, active);
  }

  function isMinter(address minter) public view returns (bool) {
    return _minters[minter];
  }

  function mint(address to, uint256 tokenId) public {
    if (!isMinter(_msgSender())) revert NotAMinter();
    _mint(to, tokenId);
  }

  function isTrustee() external pure override returns (bytes4) {
    return Trustee.isTrustee.selector;
  }

  function supportsInterface(bytes4 interfaceId) public view override(ERC721) returns (bool) {
    return (interfaceId == type(ITrustee).interfaceId) || super.supportsInterface(interfaceId);
  }
}
