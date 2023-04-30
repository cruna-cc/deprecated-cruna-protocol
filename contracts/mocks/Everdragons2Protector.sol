// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

import "../protector/Protector.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Everdragons2Protector is Protector, OwnableUpgradeable, UUPSUpgradeable {
  event TokenURIFrozen();
  event TokenURIUpdated(string uri);

  error FrozenTokenURI();

  string private _baseTokenURI;
  bool private _baseTokenURIFrozen;

  function initialize() public initializer {
    __Ownable_init();
    __UUPSUpgradeable_init();
    __Protector_init("Everdragons2 Protectors", "E2P");
    _baseTokenURI = "https://everdragons2.com/protector/";
  }

  // required by UUPSUpgradeable
  function _authorizeUpgrade(address) internal override onlyOwner {}

  // required by @cruna/ds-protocol
  function _canAddSubordinate() internal override onlyOwner {}

  function version() public pure virtual returns (string memory) {
    return "1.0.0";
  }

  // TODO implement minting functions

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
