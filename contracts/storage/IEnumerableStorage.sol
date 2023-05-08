// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

interface IEnumerableStorage {
  struct Asset {
    address assetAddress;
    uint256 id;
    uint256 amount;
  }

  function getAmount(uint256 protectedId, address assetAddress, uint256 id) external view returns (uint256);

  function getAssets(uint256 protectedId) external view returns (Asset[] memory);

  function countAssets(uint256 protectedId) external view returns (uint256);

  function getAssetByIndex(uint256 protectedId, uint256 index) external view returns (Asset memory);

  function getAssetByKey(uint256 protectedId, bytes32 key) external view returns (Asset memory);

  function getAssetKey(uint256 protectedId, uint256 index) external view returns (bytes32);

  function getAssetsAddresses(uint256 protectedId, uint256 offset, uint256 limit) external view returns (address[] memory);
}
