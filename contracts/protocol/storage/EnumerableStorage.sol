// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.17;
pragma experimental ABIEncoderV2;

// Author: Francesco Sullo <francesco@sullo.co>

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "../interfaces/IEnumerableStorage.sol";
import "hardhat/console.sol";

contract EnumerableStorage is IEnumerableStorage {
  using SafeMathUpgradeable for uint256;

  mapping(uint256 => Asset[]) private _assets;
  mapping(bytes32 => uint256) private _assetIndexes;

  function _key(
    uint256 protectorId,
    address assetAddress,
    uint256 id
  ) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(protectorId, assetAddress, id));
  }

  function _key(uint256 protectorId, Asset memory asset) internal pure returns (bytes32) {
    return _key(protectorId, asset.assetAddress, asset.id);
  }

  function _save(
    uint256 protectorId,
    address assetAddress,
    uint256 id,
    int256 amount
  ) internal {
    bytes32 key = _key(protectorId, assetAddress, id);
    if (_assetIndexes[key] > 0) {
      // will revert if newAmount is negative
      uint256 newAmount;
      if (amount < 0) {
        newAmount = _assets[protectorId][_assetIndexes[key] - 1].amount.sub(uint256(-amount));
      } else {
        newAmount = _assets[protectorId][_assetIndexes[key] - 1].amount.add(uint256(amount));
      }
      if (newAmount == 0) {
        // if the changing element is not the last one
        if (_assets[protectorId].length > _assetIndexes[key]) {
          // move last element to the position of the element to delete
          _assetIndexes[_key(protectorId, _assets[protectorId][_assets[protectorId].length - 1])] = _assetIndexes[key];
          _assets[protectorId][_assetIndexes[key] - 1] = _assets[protectorId][_assets[protectorId].length - 1];
        }
        _assets[protectorId].pop();
        delete _assetIndexes[key];
      } else {
        _assets[protectorId][_assetIndexes[key] - 1].amount = newAmount;
      }
    } else {
      // will revert if amount is negative
      _assets[protectorId].push(Asset(assetAddress, id, uint256(amount)));
      _assetIndexes[key] = _assets[protectorId].length;
    }
  }

  function getAmount(
    uint256 protectorId,
    address assetAddress,
    uint256 id
  ) public view override returns (uint256) {
    bytes32 key = _key(protectorId, assetAddress, id);
    if (_assetIndexes[key] > 0) {
      return _assets[protectorId][_assetIndexes[key] - 1].amount;
    }
    return 0;
  }

  function getAssets(uint256 protectorId) public view override returns (Asset[] memory) {
    return _assets[protectorId];
  }

  function countAssets(uint256 protectorId) public view override returns (uint256) {
    return _assets[protectorId].length;
  }

  function getAssetByIndex(uint256 protectorId, uint256 index) public view override returns (Asset memory) {
    return _assets[protectorId][index];
  }

  function getAssetByKey(uint256 protectorId, bytes32 key) public view override returns (Asset memory) {
    return _assets[protectorId][_assetIndexes[key] - 1];
  }

  function getAssetKey(uint256 protectorId, uint256 index) public view override returns (bytes32) {
    return _key(protectorId, _assets[protectorId][index].assetAddress, _assets[protectorId][index].id);
  }

  function getAssetsAddresses(
    uint256 protectorId,
    uint256 offset,
    uint256 limit
  ) public view override returns (address[] memory) {
    address[] memory assets = new address[](_assets[protectorId].length);
    if (limit > _assets[protectorId].length) {
      limit = _assets[protectorId].length;
    }
    for (uint256 i = offset; i < limit; i++) {
      assets[i] = _assets[protectorId][i].assetAddress;
    }
    return assets;
  }

  uint256[50] private __gap;
}
