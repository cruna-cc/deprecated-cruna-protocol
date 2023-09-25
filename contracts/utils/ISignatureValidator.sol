// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISignatureValidator {
  function isSignatureValidator() external pure returns (bytes4);

  function signSetProtector(
    address tokenOwner,
    address protector,
    bool active,
    uint256 timestamp,
    uint256 validFor,
    bytes calldata signature
  ) external view returns (address);

  function signTransferRequest(
    uint256 tokenId,
    address to,
    uint256 timestamp,
    uint256 validFor,
    bytes calldata signature
  ) external view returns (address);

  function signEjectRequest(
    uint256 owningTokenId,
    uint256 timestamp,
    uint256 validFor,
    bytes calldata signature
  ) external view returns (address);

  function signRecipientRequest(
    address owner,
    address recipient,
    uint256 level,
    uint256 timestamp,
    uint256 validFor,
    bytes calldata signature
  ) external view returns (address);

  function signBeneficiaryRequest(
    address owner,
    address beneficiary,
    uint256 status,
    uint256 timestamp,
    uint256 validFor,
    bytes calldata signature
  ) external view returns (address);

  function signWithdrawsRequest(
    uint256 owningTokenId,
    uint256[] memory tokenTypes,
    address[] memory assets,
    uint256[] memory ids,
    uint256[] memory amounts,
    address[] memory beneficiaries,
    uint256 timestamp,
    uint256 validFor,
    bytes calldata signature
  ) external view returns (address);
}
