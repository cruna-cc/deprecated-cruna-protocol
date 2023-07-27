// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol" as Ownable;
import {ClusteredERC721, Strings} from "./ClusteredERC721.sol";

// reference implementation of a Cruna Vault
contract CrunaVault is ClusteredERC721 {
  using Strings for uint256;

  event TokenURIFrozen();
  event TokenURIUpdated(string uri);
  error FrozenTokenURI();
  error NotAMinter();

  string private _baseTokenURI;
  bool private _baseTokenURIFrozen;

  // clustered

  constructor(string memory baseUri_, address tokenUtils) ClusteredERC721("Cruna Vault", "CRUNA", tokenUtils) {
    _baseTokenURI = baseUri_;
  }

  function safeMint(uint256 clusterId, address to) public {
    if (clusters[clusterId].owner == address(0)) revert ClusterNotFound();
    if (clusterMinters[clusterId] != _msgSender() && clusters[clusterId].owner != msg.sender) revert NotClusterOwner();
    if (clusters[clusterId].nextTokenId > clusters[clusterId].firstTokenId + clusters[clusterId].size - 1) revert ClusterFull();
    _safeMint(to, clusters[clusterId].nextTokenId++);
  }

  // set factory to 0x0 to disable a factory
  function allowFactoryFor(address factory, uint256 clusterId) external {
    if (clusters[clusterId].owner != msg.sender) revert NotClusterOwner();
    if (factory != address(0)) {
      clusterMinters[clusterId] = factory;
    } else {
      delete clusterMinters[clusterId];
    }
  }

  //
  //  function _baseURI() internal view virtual override returns (string memory) {
  //    return _baseTokenURI;
  //  }
  //
  //  function updateTokenURI(string memory uri) external onlyOwner {
  //    if (_baseTokenURIFrozen) {
  //      revert FrozenTokenURI();
  //    }
  //    // after revealing, this allows to set up a final uri
  //    _baseTokenURI = uri;
  //    emit TokenURIUpdated(uri);
  //  }
  //
  //  function freezeTokenURI() external onlyOwner {
  //    _baseTokenURIFrozen = true;
  //    emit TokenURIFrozen();
  //  }
  //
  function contractURI() public view returns (string memory) {
    return string(abi.encodePacked(_baseTokenURI, "cruna-vault"));
  }
}
