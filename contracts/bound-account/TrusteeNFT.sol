// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../vaults/IFlexiVaultExtended.sol";

// @dev The NFTs owning the bound account are all minted from this contract.
// The minter must be an active FlexiVault
// The NFT can be ejected from the FlexiVault and transferred to the owner
contract TrusteeNFT is ERC721, Ownable {
  event MinterSet(address indexed minter, bool active);
  error NotAMinter();
  error MinterNotAFlexiVault();

  mapping(address => bool) private _minters;

  constructor() ERC721("TrusteeNFT", "oNFT") {}

  // the minter must be an
  function setMinter(address minter, bool active) public onlyOwner {
    if (active) {
      try IFlexiVault(minter).isFlexiVault() returns (bytes4 result) {
        if (result != IFlexiVault.isFlexiVault.selector) revert MinterNotAFlexiVault();
      } catch {
        revert MinterNotAFlexiVault();
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
}
