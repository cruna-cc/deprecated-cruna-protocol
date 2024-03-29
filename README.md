# Cruna Core Protocol

## THIS REPO CONTAINS THE FIRST VERSION OF THE CRUNA PROTOCOL, NEVER DEPLOYED IN PRODUCTION, AND REPLACED BY  

https://github.com/cruna-cc/cruna-vault

------


The Cruna Protocol is an NFT-based system that enables secure consolidation and management of digital assets across multiple blockchains. It allows users to link ownership of their assets to NFTs called Cruna Vaults, providing a unified interface for managing and transferring the assets.

The protocol implements robust security mechanisms including multi-factor authentication via entity termed Protectors. It also facilitates scheduled distribution and inheritance of assets held in the vaults. The first application in the protocol is the Flexi Vault, which offers safe storage and movement of tokens and NFTs.

The Cruna Protocol aims to tackle key challenges like fragmented asset control, security risks, and lack of flexible distribution options faced by crypto users today. It expands the utility of NFTs beyond collectibles to active asset management functionalities.

## Key Components

### 1. Cruna Vault, Non-Fungible Tokens (NFTs) and Protectors

The Cruna Vault represents the core of the Cruna Core Protocol. It is an NFT that a user must own to manage the vault, playing a crucial role in the structure and functionality of the protocol.

The owning token within this structure functions as a standard NFT, providing a bridge between the owner and the application(s) associated with the vault. To enhance security, the protocol incorporates ProtectedERC721 contracts—NFTs capable of adding special wallets, termed 'Protectors'.

The Protectors play a critical role in enhancing the security of the protocol. In the Cruna Vault, the NFT owner can appoint one or more Protectors. While Protectors lack the authority to initiate NFT transfers independently, they must pre-approve any transfer requests initiated by the owner, signing the request. This two-tier authentication mechanism significantly reduces the risk of unauthorized NFT transfers, even in cases where the owner's account may be compromised.

To add flexibility to the system, the vault owner can set Allowlisted recipient that can receive assets without requiring the pre-approval from a protector. This is particularly useful in a company environment, where some wallets receiving assets do not need approval. This feature must be used carefully, because can make the Protectors useless.

Once the owner designates the first Protector, the second Protector needs the pre-approval of the first protector to be set up. For similar reasons, a Protector cannot be removed unilaterally by the owner but must provide a valid signature.

It is advisable to assign multiple Protectors to maintain access to the vault even if one Protector becomes inaccessible. Reasonably, if there is a need for more than two protectors, it may make sense to transfer the ownership of the vault to a multisig wallet.

#### Vault Operators

Alongside Protectors, the vault can also have operators—wallets that have the authority to manage the assets in the vault akin to the owner. For example, an owner may possess an NFT in an externally owned account (EOA) wallet like MetaMask and set two protectors using a cold wallet, like a Ledger, and a secondary wallet that hasn't been imported into MetaMask. This setup ensures that the owner can interact with the NFT without the risk of being phished, as any actual token transfer would fail without the approval of one of the protectors.

A real-world example can be a CEO who purchases two vaults—one for Marketing and another for Development. The CEO can appoint the CFO as a Protector, and the CTO and CMO as operators for the respective vaults.

While it is possible for an owner not to set any Protectors and manage the vault directly, this approach is not recommended due to potential security risks.

#### Asset Recovery and Beneficiary Management

The Cruna Vault provides a mechanism for asset recovery in case the owner loses access or passes away. The owner can designate beneficiaries and set a recovery quorum and expiration timeframe.

Before the expiry, the owner has to trigger a proof-of-life event to indicate they still retain access. If the event isn't triggered, a designated beneficiary can initiate the recovery process and suggest a recipient wallet.

Other beneficiaries can confirm the transfer or reject it. If rejected, they can suggest an alternate recipient. The protocol is designed to prevent blocking of the process by hostile beneficiaries.

This beneficiary management system enables orderly transfer of assets to successors in case of incapacity or demise of the vault owner. It provides individuals and entities a way to ensure business continuity and asset inheritance in a secure manner.

### 2. The Flexi Vault

The Flexi Vault is a smart-contract managed by the Cruna Vault to securely store and protect assets (ERC20, ERC721, ERC1155). The ownership of the Flexi Vault is linked to the owning NFT, signifying that transferring the ownership of the NFT also transfers the ownership of the Flexi Vault.

Since the Cruna Vault is a ProtectedERC721, the Flexi Vault inherits its security features. When the owner of the NFT has designated a Protector, any asset movement from the Flexi Vault to external wallets or other vaults not owned by the same owner necessitates a signature from the Protector, enhancing the security of asset transfers.

On deployment, the Flexi Vault initiates a CrunaWallet, a distinct NFT designed to manage smart contract wallets using [ERC6551](https://eips.ethereum.org/EIPS/eip-6551) bound accounts. Any tokenId of the CrunaWallet is initially owned by the Flexi Vault and, by extension, by the Vault's owner.

The owner reserves the right to eject their CrunaWallet at any moment, facilitating the transfer of an ID ownership from the Flexi Vault to the Cruna Vault's owner. This action can be reversed in the future, thereby reactivating the vault and resuming asset management.

### 3. CrunaWallet, Smart Contracts, and Vault Migration

The CrunaWallet, as an integral part of the Cruna Vault, is designed to offer flexibility in managing smart contract wallets. It can be ejected and re-injected into the vault, enabling migration between different versions of the vault. This feature is crucial considering that all smart contracts used in the Cruna Core Protocol are immutable, barring the exception of the ERC6551 bound account.

After activation, the CrunaWallet functions as an upgradeable contract. However, its uniqueness lies in the exclusive authority granted to the owner of the Cruna Vault: only they can initiate an upgrade. This ensures that the decision to transition the CrunaWallet to a new version remains entirely in the hands of the Cruna Vault's owner.

#### Vault Migration Process

The process of upgrading a Cruna Vault to a new version is straightforward, although it requires careful steps due to the immutable nature of smart contracts.

1. **Deployment of the New Contract**: The first step involves deploying the new contract for the upgraded Cruna Vault (V2).
2. **Eject the CrunaWallet from the Old Vault**: The owner must then eject the CrunaWallet from the current vault (V1). This action transfers the ownership of the CrunaWallet ID from the Flexi Vault to the owner of the Cruna Vault.
3. **Re-Inject the CrunaWallet into the New Vault**: The final step is to re-inject the ejected CrunaWallet into the new vault (V2). This effectively transfers the management of the assets from the old vault to the new one.

Through this migration process, users can seamlessly transition to newer versions of the Cruna Vault, ensuring they can take advantage of new features and improved security measures while maintaining the control and security of their assets.

### Use Cases

- Consolidate all assets of a collection into a single Vault, allowing a seamless transfer of ownership without needing to move each asset individually. This offers significant improvements in security and user experience.

- Create asset bundles and list them for sale as a single NFT on popular marketplaces like OpenSea.

- Deposit vested assets into a Flexi Vault for scheduled distribution to investors, team members, etc. Note that for this to work, the asset must be capable of managing the vesting schedule. In a future version of the Cruna Core Protocol, a Flexi Distributor will be introduced to handle the vesting of any assets.

- Create a Flexi Vault for a DAO, allowing the DAO to manage its assets collectively.

- Use a Cruna Vault to give assets to siblings. For example, a user can set a vault for his kids and when they are adult can just transfer the Vault to them, instead of transferring the assets one by one.

- A company can put their reserves in a vault, "owned" by the CEO, with an inheritance process allowing the board directors to recover the assets in case the CEO becomes unavailable for any reason.

### Future developments

As the Cruna Core Protocol continues to evolve, many dditions are currently in the pipeline: the Distributor Vault and the Inheritance Vault. Each of these vaults caters to specific needs, expanding the applications of the Cruna Core Protocol in the realms of asset management and security.

#### Distributor Vault

The Distributor Vault is a specialized vault designed to streamline the process of scheduled asset distribution. An entity can pre-load this vault with assets, which are then automatically distributed to the designated beneficiaries according to a predetermined schedule.

This functionality can be advantageous in numerous scenarios. For instance, a company wishing to distribute its governance tokens (ERC20) can purchase a Distributor Vault, fill it with the appropriate tokens, and set a vesting schedule. Once the NFT ownership of the Distributor Vault is given to an investor, the company no longer needs to actively manage token distribution. The tokens will be vested and delivered automatically as per the set schedule, providing the investor with an assurance of receiving their assets in a timely manner. This system is not only beneficial for investors, but it can also be employed for the scheduled distribution of tokens to employees, advisors, and other stakeholders.

#### Hardware protectors

Within the framework of the Cruna Protocol, we're introducing specialized USB keys designed to further bolster the security and functionality of our platform. These USB devices implement a streamlined wallet architecture singularly focused on executing typed V4 signatures. By narrowing down the wallet's capabilities to this specific type of signature, we ensure a higher level of protection against potential threats. When integrated with Cruna's unique Vault system, these USB keys serve as an inexpensive and robust protectors, amplifying the assurance our users have in the safety of their consolidated assets. This innovation reflects Cruna Protocol's commitment to staying at the forefront of cryptographic security, providing our users with tools that are both powerful and user-friendly.

#### Privacy protected Vaults

A new family of Zero Knowledge based vaults will allow a high level of privacy.

## History

**1.5.0**

- Using erc6551 as an external dependency
- Making upgradeable account only upgradeable by the vault owner
- Remove immutable account option
- Allowing migration of the vault to a new version (ejecting from V1 and reinjecting in V2)
- Adding beneficiaries that can inherit the wallet if a proof-of-life is not provided
- Adding allowlisted safe recipients to skip the protection (feature to be used carefully)
- Changing the way how protectors allows transfers. Before the protector had to make a transaction to start the transfer than later was completed by the owner. In the new approach, the protectors sign the transfer and the owner can complete it with a single transaction, using protectors' signature. This also prepare for future hardware protectors that do not need to own value to perform a transaction.
- Moving from simple message signature to typed V4 signatures to reduce the risk of misleading messages allowing phishing and possible fraud.

**1.4.1**

- Add support for receiving ERC777 in ERC6551Account

**1.4.0**

- Full refactor to improve the upgradeability of the vaults, despite being immutable
- Remove ERC7108, not really needed in this stage

**1.2.6**

- Integrate ClusteredERC721 to manage clusters inside the Cruna Vault
- Allow the user to choose between an immutable bound-account and an upgradeable one
- Renames OwnerNFT to CrunaWallet
- Rename TransparentVault to FlexiVault

**1.2.5**

- Add clusters to the CrunaVault reference implementation, right now inside mocks
- Add missing protectedEjectAccount function, when protectors exist
- Add eject/inject functions to interface also missed in previous PR
- Optimize the size of FlexiVault moving some functions to TokenUtils that now works as an external contract, instead of being extended
- Change isSignatureUsed adding explicitly tokenId as a parameter
- Make little change to tests to let them pass after the changes
- Rename Status.REMOVABLE to Status.RESIGNED to align it with the changed names of the functions

**1.2.4**

- Add `validFor` field in signature
- Allow the protector to invalidate signatures

**1.2.3**

- Move from double transaction when there are active protectors to single transaction with validation signature
- Add batch functions for deposits and withdrawals/transfers
- Force the owner of the vault to be a ProtectedERC721

**1.2.0**

- Park the Flexi Vault contracts, as they are not used in the current version of the protocol
- Introduce an airdroppable version of the vault, using ERC6551 to handle the assets
- Add in the lockable folder the ERC721Lockable contracts, taken from [ndujaLabs/erc721lockable](https://github.com/ndujalabs/erc721lockable) repo, for completeness
- Make the CrunaSafebox not upgradeable for improved trust, allowing migration to V2 in the future
- Make the Protected not upgradeable and able to have more than one protector
- Modified the OwnerNFT to separate the roles between owner and minters

**1.0.3**

- Remove some unused variables from TransparentSafeBox
- Modify TransparentSafeBox so that FlexiVaultEnumerable can extend it
- Check at initialization time if the owning token is a ProtectedERC721 and saves it in a variable

**1.0.2**

- Move the vault from extending ERC721Subordinate to NFTOwned
- Rename the Protector as ERC721Protected
- **1.0.1**

- Improve publish script

**1.0.0-beta.7**

- Putting in this repo, code previously in @cruna/ds-protocol.

**1.0.0-beta.4**

- Make the protector approvable by default. The owner will be pushed to make it not-approvable when depositing the first asset in the Transparent Vault.

**1.0.0-beta.3**

- Remove post-install, creating issues when loaded as a dependency

**1.0.0-beta.2**

- Adding \_\_gap variables to Transparent Vault contracts to allow for future upgrades

**1.0.0-beta.1**

- ready to publish it as an npm package

**0.1.5**

- Moving to use @cruna/ds-protocol instead of @ndujalabs/erc721subordinate
- Adding batch minting functions

**0.1.4**

- Optimize mappings using keccak256

**0.1.3**

- Renaming the protocol
- Separating the implementations in the `protected` folder

**0.1.2**

- Add a starter, i.e., a second wallet that must start the transfer of the protector NFT
- If a starter is active, the protected will only allow transfers of assets between protectors not owned by the same owner only if the transfer is started by the starter

**0.1.1**

- Separate ERC721Attributable from IProtector interface for clarity and generality

**0.1.0**

- first version

## License

Copyright (C) 2023 Cruna

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You may have received a copy of the GNU General Public License
along with this program. If not,
see <https://www.gnu.org/licenses/gpl-3.0.en.html>.
