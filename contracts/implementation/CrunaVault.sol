// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../protected-nft/ProtectedERC721.sol";
import "../utils/IERC7108.sol";

// reference implementation of a Cruna Vault
contract CrunaVault is ProtectedERC721, IERC7108 {
  using Strings for uint256;

  event TokenURIFrozen();
  event TokenURIUpdated(string uri);
  error FrozenTokenURI();
  error NotAMinter();

  string private _baseTokenURI;
  bool private _baseTokenURIFrozen;

  // clustered

  error ZeroAddress();
  error NotClusterOwner();
  error SizeTooLarge();
  error ClusterFull();
  error ClusterNotFound();

  struct Cluster {
    address owner;
    uint32 size;
    uint32 firstTokenId;
    uint32 nextTokenId;
    string name;
    string symbol;
    string baseTokenURI;
  }

  mapping(uint256 => Cluster) public clusters;
  mapping(address => uint256[]) public clusterIdByOwners;
  uint256 public maxSize = 100000;
  uint256 private _nextClusterId;

  constructor(string memory baseUri_) ProtectedERC721("Cruna Vault V1", "CRUNA") {
    _baseTokenURI = baseUri_;
  }

  function addCluster(
    string memory name,
    string memory symbol,
    string memory baseTokenURI,
    uint256 size,
    address clusterOwner_
  ) public override onlyOwner {
    if (clusterOwner_ == address(0)) revert ZeroAddress();
    if (size > maxSize) revert SizeTooLarge();
    uint256 lastTokenIdInClusters;
    if (_nextClusterId > 0) {
      lastTokenIdInClusters = clusters[_nextClusterId - 1].firstTokenId + clusters[_nextClusterId - 1].size - 1;
    }
    clusters[_nextClusterId] = Cluster({
      name: name,
      symbol: symbol,
      baseTokenURI: baseTokenURI,
      owner: clusterOwner_,
      firstTokenId: uint32(lastTokenIdInClusters + 1),
      size: uint32(size),
      nextTokenId: uint32(lastTokenIdInClusters + 1)
    });
    clusterIdByOwners[clusterOwner_].push(_nextClusterId);
    emit ClusterAdded(_nextClusterId, name, symbol, baseTokenURI, size, clusterOwner_);
    _nextClusterId++;
  }

  function clustersByOwner(address owner) public view returns (uint256[] memory) {
    return clusterIdByOwners[owner];
  }

  function _binarySearch(uint x) internal view returns (uint) {
    if (_nextClusterId == 0) {
      return type(uint).max;
    }

    uint start;
    uint end = _nextClusterId - 1;
    uint mid;

    while (start <= end) {
      mid = start + (end - start) / 2;
      uint first = uint(clusters[mid].firstTokenId);
      uint next = uint(clusters[mid].firstTokenId + clusters[mid].size);
      if (x >= first && x < next) {
        return mid;
      } else if (x >= next) {
        if (mid == end) {
          break;
        }
        start = mid + 1;
      } else {
        if (mid == 0) {
          break;
        }
        end = mid - 1;
      }
    }

    // If we reach here, then the element was not present
    return type(uint).max;
  }

  function clusterOf(uint256 tokenId) public view override returns (uint256) {
    uint256 clusterId = _binarySearch(tokenId);
    if (clusterId == type(uint256).max) revert ClusterNotFound();
    return clusterId;
  }

  function nameOf(uint256 clusterId) public view override returns (string memory) {
    return clusters[clusterId].name;
  }

  function symbolOf(uint256 clusterId) public view override returns (string memory) {
    return clusters[clusterId].symbol;
  }

  function rangeOf(uint256 clusterId) public view override returns (uint256, uint256) {
    return (clusters[clusterId].firstTokenId, clusters[clusterId].firstTokenId + clusters[clusterId].size - 1);
  }

  function clusterOwner(uint256 clusterId) public view override returns (address) {
    return clusters[clusterId].owner;
  }

  function clustersCount() public view override returns (uint256) {
    return _nextClusterId;
  }

  // This function was originally part of the interface but it was removed
  // to leave the implementer full freedom about how to manage the ownership
  function transferClusterOwnership(uint256 clusterId, address newOwner) public {
    if (newOwner == address(0)) revert ZeroAddress();
    if (clusters[clusterId].owner != msg.sender) revert NotClusterOwner();
    clusters[clusterId].owner = newOwner;
    emit ClusterOwnershipTransferred(clusterId, newOwner);
  }

  function normalizedTokenId(uint256 tokenId) public view override returns (uint256) {
    uint256 clusterId = _binarySearch(tokenId);
    if (clusterId == type(uint32).max) revert ClusterNotFound();
    return tokenId - clusters[clusterId].firstTokenId + 1;
  }

  function safeMint(uint256 clusterId, address to) public {
    if (clusters[clusterId].owner == address(0)) revert ClusterNotFound();
    if (clusters[clusterId].owner != msg.sender) revert NotClusterOwner();
    if (clusters[clusterId].nextTokenId > clusters[clusterId].firstTokenId + clusters[clusterId].size - 1) revert ClusterFull();
    _safeMint(to, clusters[clusterId].nextTokenId++);
  }

  // token URI management

  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    _requireMinted(tokenId);
    uint256 clusterId = _binarySearch(tokenId);
    string memory baseURI = clusters[clusterId].baseTokenURI;
    tokenId -= clusters[clusterId].firstTokenId - 1;
    return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
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
    return string(abi.encodePacked(_baseTokenURI, "cruna-vault"));
  }
}
