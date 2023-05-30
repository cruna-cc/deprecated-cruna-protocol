// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../vaults/ITransparentVaultExtended.sol";

// @dev The NFTs owning the bound account are all minted from this contract.
// The minter must be an active TransparentVault
// The NFT can be ejected from the TransparentVault and transferred to the owner
contract OwnerNFT is ERC721, Ownable {
  event MinterSet(address indexed minter, bool active);
  error NotAMinter();
  error MinterNotATransparentVault();

  mapping(address => bool) private _minters;

  constructor() ERC721("OwnerNFT", "oNFT") {}

  // the minter must be an
  function setMinter(address minter, bool active) public onlyOwner {
    if (active) {
      try ITransparentVault(minter).isTransparentVault() returns (bytes4 result) {
        if (result != ITransparentVault.isTransparentVault.selector) revert MinterNotATransparentVault();
      } catch {
        revert MinterNotATransparentVault();
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
