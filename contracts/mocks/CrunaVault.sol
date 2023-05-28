// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../protected-nft/ProtectedERC721.sol";

// reference implementation of a Cruna Vault
contract CrunaVault is ProtectedERC721 {
  event TokenURIFrozen();
  event TokenURIUpdated(string uri);
  event ClusterAdded(uint256 index, string name, address minter);

  error FrozenTokenURI();
  error NotAMinter();

  string private _baseTokenURI;
  bool private _baseTokenURIFrozen;

  struct Cluster {
    string name;
    address minter;
    uint nextTokenId;
  }
  mapping(uint256 => Cluster) public clusters;
  mapping(address => uint256) public clusterIdByMinters;
  uint internal _nextClusterId = 1;

  constructor() ProtectedERC721("Cruna Vault V1", "CRUNA") {
    _baseTokenURI = "https://meta.cruna.cc/vault/v1/";
    addCluster("", msg.sender);
  }

  function addCluster(string memory name, address clusterMinter) public onlyOwner {
    if (clusterMinter == address(0)) revert NoZeroAddress();
    if (bytes(name).length == 0) {
      name = "Cruna Vault";
    } else {
      name = string(abi.encodePacked(name, " Cruna Vault"));
    }
    clusters[_nextClusterId] = Cluster(name, clusterMinter, 1 + ((_nextClusterId - 1) * 1e6));
    clusterIdByMinters[clusterMinter] = _nextClusterId;
    emit ClusterAdded(_nextClusterId++, name, clusterMinter);
  }

  function safeMint(address to) public {
    uint256 clusterId = clusterIdByMinters[msg.sender];
    if (clusterId == 0) revert NotAMinter();
    _safeMint(to, clusters[clusterId].nextTokenId++);
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
