// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

import "../../transparent-vault/TransparentVaultEnumerable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Everdragons2TransparentVaultEnumerable is TransparentVaultEnumerable, OwnableUpgradeable, UUPSUpgradeable {
  event TokenURIFrozen();
  event TokenURIUpdated(string uri);

  error FrozenTokenURI();

  string private _baseTokenURI;
  bool private _baseTokenURIFrozen;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(address protector) public initializer {
    __Ownable_init();
    __UUPSUpgradeable_init();
    __TransparentVaultEnumerable_init(protector, "Everdragons2 Transparent Vault", "E2TV");
    _baseTokenURI = "https://everdragons2.com/vault/";
  }

  // required by UUPSUpgradeable
  function _authorizeUpgrade(address) internal override onlyOwner {}

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
