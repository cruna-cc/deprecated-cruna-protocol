// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";

import {ISignatureValidator} from "./ISignatureValidator.sol";

contract SignatureValidator is EIP712, ISignatureValidator {
  error TimestampZero();

  constructor(string memory name, string memory version) EIP712(name, version) {}

  function isSignatureValidator() external pure override returns (bytes4) {
    return SignatureValidator.isSignatureValidator.selector;
  }

  function signSetProtector(
    address tokenOwner,
    address protector,
    bool active,
    uint256 timestamp,
    uint256 validFor,
    bytes calldata signature
  ) external view returns (address) {
    if (timestamp == 0) revert TimestampZero();
    bytes32 digest = _hashTypedDataV4(
      keccak256(
        abi.encode(
          keccak256("Auth(address tokenOwner,address protector,bool active,uint256 timestamp,uint256 validFor)"),
          tokenOwner,
          protector,
          active,
          timestamp,
          validFor
        )
      )
    );
    return ECDSA.recover(digest, signature);
  }

  function signTransferRequest(
    uint256 tokenId,
    address to,
    uint256 timestamp,
    uint256 validFor,
    bytes calldata signature
  ) external view returns (address) {
    if (timestamp == 0) revert TimestampZero();
    bytes32 digest = _hashTypedDataV4(
      keccak256(
        abi.encode(
          keccak256("Auth(uint256 tokenId,address to,uint256 timestamp,uint256 validFor)"),
          tokenId,
          to,
          timestamp,
          validFor
        )
      )
    );
    return ECDSA.recover(digest, signature);
  }

  function signEjectRequest(
    uint256 owningTokenId,
    uint256 timestamp,
    uint256 validFor,
    bytes calldata signature
  ) external view returns (address) {
    if (timestamp == 0) revert TimestampZero();
    bytes32 digest = _hashTypedDataV4(
      keccak256(
        abi.encode(
          keccak256("Auth(uint256 owningTokenId,uint256 timestamp,uint256 validFor)"),
          owningTokenId,
          timestamp,
          validFor
        )
      )
    );
    return ECDSA.recover(digest, signature);
  }

  function signRecipientRequest(
    address owner,
    address recipient,
    uint256 level,
    uint256 timestamp,
    uint256 validFor,
    bytes calldata signature
  ) external view returns (address) {
    if (timestamp == 0) revert TimestampZero();
    bytes32 digest = _hashTypedDataV4(
      keccak256(
        abi.encode(
          keccak256("Auth(address owner,address recipient,uint256 level,uint256 timestamp,uint256 validFor)"),
          owner,
          recipient,
          level,
          timestamp,
          validFor
        )
      )
    );
    return ECDSA.recover(digest, signature);
  }

  function signBeneficiaryRequest(
    address owner,
    address beneficiary,
    uint256 status,
    uint256 timestamp,
    uint256 validFor,
    bytes calldata signature
  ) external view returns (address) {
    if (timestamp == 0) revert TimestampZero();
    bytes32 digest = _hashTypedDataV4(
      keccak256(
        abi.encode(
          keccak256("Auth(address owner,address beneficiary,uint256 status,uint256 timestamp,uint256 validFor)"),
          owner,
          beneficiary,
          status,
          timestamp,
          validFor
        )
      )
    );
    return ECDSA.recover(digest, signature);
  }

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
  ) external view returns (address) {
    if (timestamp == 0) revert TimestampZero();
    bytes32 digest = _hashTypedDataV4(
      keccak256(
        abi.encode(
          keccak256(
            "Auth(uint256 owningTokenId,uint256[] memory tokenTypes,address[] memory assets,uint256[] memory ids,uint256[] memory amounts,address[] memory beneficiaries,uint256 timestamp,uint256 validFor)"
          ),
          owningTokenId,
          tokenTypes,
          assets,
          ids,
          amounts,
          beneficiaries,
          timestamp,
          validFor
        )
      )
    );
    return ECDSA.recover(digest, signature);
  }
}
