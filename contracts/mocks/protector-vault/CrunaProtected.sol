// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../../protected-nft/ProtectedERC721.sol";

contract CrunaProtected is ProtectedERC721, Ownable {
  event TokenURIFrozen();
  event TokenURIUpdated(string uri);

  error FrozenTokenURI();

  string private _baseTokenURI;
  bool private _baseTokenURIFrozen;

  uint256 private _nextTokenId;

  constructor() ProtectedERC721("Cruna Protected", "CRUNA") {
    _baseTokenURI = "https://meta.cruna.cc/protected/";
  }

  function version() public pure virtual returns (string memory) {
    return "1.0.0";
  }

  // this is used for testing
  function safeMint(address to, uint256 tokenId) public onlyOwner {
    _safeMint(to, tokenId);
  }

  // this is used for simulations
  function safeMint2(address to) public onlyOwner {
    _safeMint(to, ++_nextTokenId);
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return _baseTokenURI;
  }

  function updateTokenURI(string memory uri) external onlyOwner {
    if (_baseTokenURIFrozen) {
      revert FrozenTokenURI();
    }
    // after revealing, this allows to set up a final uri
    _baseTokenURI = uri;
    emit TokenURIUpdated(uri);
  }

  function freezeTokenURI() external onlyOwner {
    _baseTokenURIFrozen = true;
    emit TokenURIFrozen();
  }

  function contractURI() public view returns (string memory) {
    return string(abi.encodePacked(_baseTokenURI, "0"));
  }

  function getProtectedERC721InterfaceId() public pure returns (bytes4) {
    return type(IProtectedERC721).interfaceId;
  }
}
