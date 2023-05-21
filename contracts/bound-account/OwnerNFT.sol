// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../vault/ISafeBox.sol";

// @dev The NFTs owning the bound account are all minted from this contract.
// The minter must be an active SafeBox
// The NFT can be ejected from the SafeBox and transferred to the owner
contract OwnerNFT is ERC721, Ownable {
  event MinterSet(address indexed minter, bool active);
  error NotAMinter();
  error MinterNotASafeBox();

  mapping(address => bool) private _minters;

  modifier onlyMinter() {
    if (!_minters[_msgSender()]) revert NotAMinter();
    _;
  }

  constructor() ERC721("OwnerNFT", "oNFT") {}

  // the minter must be an
  function setMinter(address minter, bool active) public onlyOwner {
    if (active) {
      try ISafeBox(minter).isSafeBox() returns (bytes4 result) {
        if (result != ISafeBox.isSafeBox.selector) revert MinterNotASafeBox();
      } catch {}
      _minters[minter] = true;
    } else if (_minters[minter]) delete _minters[minter];
    emit MinterSet(minter, active);
  }

  function mint(address to, uint256 tokenId) public onlyMinter {
    _mint(to, tokenId);
  }
}
