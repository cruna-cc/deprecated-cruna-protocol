// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.17;

import "../../protocol/protector/Protector.sol";

contract Everdragons2Protector is Protector {
  event TokenURIFrozen();
  event TokenURIUpdated(string uri);

  error FrozenTokenURI();

  string private _baseTokenURI;
  bool private _baseTokenURIFrozen;

  function initialize(address contractOwner) public initializer {
    __Protector_init(contractOwner, "Everdragons2 Protectors", "E2P");
    _baseTokenURI = "https://everdragons2.com/protector/";
  }

  function version() public pure virtual returns (string memory) {
    return "1.0.0";
  }

  function safeMint(address to, uint256 tokenId) public onlyOwner {
    _safeMint(to, tokenId);
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
}
