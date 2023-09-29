// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";

contract SignatureValidator is EIP712 {
  constructor(string memory name, string memory version) EIP712(name, version) {}

  function verify(
    bytes memory signature,
    address signer,
    address mailTo,
    string memory mailContents
  ) external view returns (bool) {
    bytes32 digest = _hashTypedDataV4(
      keccak256(abi.encode(keccak256("Mail(address to,string contents)"), mailTo, keccak256(bytes(mailContents))))
    );
    address recoveredSigner = ECDSA.recover(digest, signature);
    return recoveredSigner == signer;
  }
}
