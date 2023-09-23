// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

// Author: Francesco Sullo <francesco@sullo.co>

//import {console} from "hardhat/console.sol";
import {IFlexiVaultManager} from "../vaults/IFlexiVaultManager.sol";
import {IActors} from "../protected/IActors.sol";

interface ITokenUtils {
  function isTokenUtils() external pure returns (bytes4);

  function isERC721(address asset) external view returns (bool);

  function isERC20(address asset) external view returns (bool);

  function isERC1155(address asset) external view returns (bool);

  function isERC777(address asset) external view returns (bool);

  function hashWithdrawRequest(
    uint256 owningTokenId,
    address asset,
    uint256 id,
    uint256 amount,
    address beneficiary,
    uint256 timestamp,
    uint256 validFor
  ) external view returns (bytes32);

  function hashWithdrawsRequest(
    uint256 owningTokenId,
    IFlexiVaultManager.TokenType[] memory tokenTypes,
    address[] memory assets,
    uint256[] memory ids,
    uint256[] memory amounts,
    address[] memory beneficiaries,
    uint256 timestamp,
    uint256 validFor
  ) external view returns (bytes32);

  function hashEjectRequest(uint256 owningTokenId, uint256 timestamp, uint256 validFor) external view returns (bytes32);

  function hashSetProtector(
    address tokenOwner,
    address protector,
    bool active,
    uint256 timestamp,
    uint256 validFor
  ) external view returns (bytes32);

  function hashUnlockProtectors(
    address tokenOwner,
    address[] memory protectors,
    uint256 timestamp,
    uint256 validFor
  ) external view returns (bytes32);

  function hashRecipientRequest(
    address owner,
    address recipient,
    IActors.Level level,
    uint256 timestamp,
    uint256 validFor
  ) external view returns (bytes32);

  function hashBeneficiaryRequest(
    address owner,
    address beneficiary,
    IActors.Status status,
    uint256 timestamp,
    uint256 validFor
  ) external view returns (bytes32);

  /**
   * @dev Returns the hash of a transfer request
   * @param tokenId The token id
   * @param to The address of the recipient
   * @param timestamp The timestamp of the transfer request
   * @return The hash of the transfer request
   */
  function hashTransferRequest(
    uint256 tokenId,
    address to,
    uint256 timestamp,
    uint256 validFor
  ) external view returns (bytes32);
}
