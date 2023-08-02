// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol" as Ownable;
import {ClusteredERC721, Strings} from "../utils/ClusteredERC721.sol";
import {IFlexiVault} from "../vaults/IFlexiVault.sol";
import {ICrunaVault} from "./ICrunaVault.sol";

// reference implementation of a Cruna Vault
contract CrunaVault is ICrunaVault, ClusteredERC721 {
  using Strings for uint256;

  event TokenURIFrozen();
  event TokenURIUpdated(string uri);
  error FrozenTokenURI();
  error NotAMinter();

  string private _baseTokenURI;
  bool private _baseTokenURIFrozen;
  address[] internal _vaults;

  constructor(
    string memory baseUri_,
    address tokenUtils,
    address actorsManager
  ) ClusteredERC721("Cruna Vault", "CRUNA", tokenUtils, actorsManager) {
    _baseTokenURI = baseUri_;
  }

  function version() external pure returns (string memory) {
    return "1.0.0";
  }

  function addVault(address vault) external override onlyOwner {
    // we are not supposed to add too many vault, it should be a rare event. So, the array should stay small enough
    // to avoid going out of gas
    try IFlexiVault(vault).isFlexiVault() returns (bytes4 result) {
      if (result != IFlexiVault.isFlexiVault.selector) revert NotAFlexiVault();
    } catch {
      revert NotAFlexiVault();
    }
    for (uint256 i = 0; i < _vaults.length; i++) {
      if (_vaults[i] == vault) revert VaultAlreadyAdded();
    }
    _vaults.push(vault);
  }

  function getVault(uint256 index) external view override returns (address) {
    return _vaults[index];
  }

  function setSignatureAsUsed(bytes calldata signature) public override {
    // callable only by a flexiVault
    for (uint256 i = 0; i < _vaults.length; i++) {
      if (_vaults[i] == _msgSender()) {
        actorsManager.setSignatureAsUsed(signature);
        return;
      }
    }
    revert NotAFlexiVault();
  }

  function _cleanOperators(uint256 tokenId) internal override {
    for (uint256 i = 0; i < _vaults.length; i++) {
      if (_vaults[i] != address(0)) {
        IFlexiVault(_vaults[i]).removeOperatorsFor(tokenId);
      }
    }
  }

  // TODO fix this for clustered NFTs
  function contractURI() public view override returns (string memory) {
    return string(abi.encodePacked(_baseTokenURI, "info"));
  }
}
