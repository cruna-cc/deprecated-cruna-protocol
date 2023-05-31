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
    string symbol;
    string baseTokenURI;
    address owner;
    uint nextTokenId;
  }
  mapping(uint256 => Cluster) public clusters;
  mapping(address => uint256) public clusterIdByOwners;
  uint internal _nextClusterId = 1;

  constructor() ProtectedERC721("Cruna Vault V1", "CRUNA") {
    _baseTokenURI = "https://meta.cruna.cc/vault/v1/";
    addCluster("", "CRUNA", _baseTokenURI, 0, address(0));
  }

  function addCluster(
    string memory name,
    string memory symbol,
    string memory baseTokenURI,
    uint256,
    address clusterOwner
  ) public onlyOwner returns (uint256) {
    if (clusterOwner == address(0)) clusterOwner = msg.sender;
    if (bytes(name).length == 0) {
      name = "Cruna Vault";
    } else {
      name = string(abi.encodePacked(name, " Cruna Vault"));
    }
    clusters[_nextClusterId] = Cluster(name, symbol, baseTokenURI, clusterOwner, 1 + ((_nextClusterId - 1) * 1e5));
    clusterIdByOwners[clusterOwner] = _nextClusterId;
    emit ClusterAdded(_nextClusterId, name, clusterOwner);
    return _nextClusterId++;
  }

  function safeMint(address to) public {
    uint256 clusterId = clusterIdByOwners[msg.sender];
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
