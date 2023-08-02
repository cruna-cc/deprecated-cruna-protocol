// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol" as Ownable;
import {ClusteredERC721, Strings} from "../utils/ClusteredERC721.sol";
import {IFlexiVault} from "../vaults/IFlexiVault.sol";

// reference implementation of a Cruna Vault
interface ICrunaVault {
  function addVault(address vault) external;

  function getVault(uint256 index) external view returns (address);

  function setSignatureAsUsed(bytes calldata signature) external;

  function contractURI() external view returns (string memory);
}
