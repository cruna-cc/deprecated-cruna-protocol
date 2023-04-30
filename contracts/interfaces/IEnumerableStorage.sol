// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

interface IEnumerableStorage {
  struct Asset {
    address assetAddress;
    uint256 id;
    uint256 amount;
  }

  function getAmount(
    uint256 protectorId,
    address assetAddress,
    uint256 id
  ) external view returns (uint256);

  function getAssets(uint256 protectorId) external view returns (Asset[] memory);

  function countAssets(uint256 protectorId) external view returns (uint256);

  function getAssetByIndex(uint256 protectorId, uint256 index) external view returns (Asset memory);

  function getAssetByKey(uint256 protectorId, bytes32 key) external view returns (Asset memory);

  function getAssetKey(uint256 protectorId, uint256 index) external view returns (bytes32);

  function getAssetsAddresses(
    uint256 protectorId,
    uint256 offset,
    uint256 limit
  ) external view returns (address[] memory);
}
