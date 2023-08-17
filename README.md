# Cruna Core Protocol

The Cruna Core Protocol lays out a distinctive hierarchy between a Non-Fungible Token (NFT) and one or more applications, where the NFT owner concurrently owns the corresponding profile of the application. This protocol augments the ERC721 standard, adding robust security mechanisms to ensure the safe and efficient interaction of an NFT with its associated applications. The first of these applications is the Cruna Vault

## Key Components

### 1. Cruna Vault, Non-Fungible Tokens (NFTs) and Protectors

The Cruna Vault represents the core of the Cruna Core Protocol. It is an NFT that a user must own to manage the vault, playing a crucial role in the structure and functionality of the protocol.

The owning token within this structure functions as a standard NFT, providing a bridge between the owner and the application(s) associated with the vault. To enhance security, the protocol incorporates ProtectedERC721 contracts—NFTs capable of adding special wallets, termed 'Protectors'.

The Protectors play a critical role in enhancing the security of the protocol. In the Cruna Vault, the NFT owner can appoint one or two Protectors. While Protectors lack the authority to initiate NFT transfers independently, they must approve any transfer requests initiated by the owner. This two-tier authentication mechanism significantly reduces the risk of unauthorized NFT transfers, even in cases where the owner's account may be compromised.

Once the owner designates the Protectors, the number of Protectors must be locked to guard against potential attacks, such as an unauthorized user adding a new Protector and initiating an NFT transfer. For similar reasons, a Protector cannot be removed unilaterally by the owner but must submit a voluntary resignation which the owner must approve.

It is advisable to assign two Protectors to maintain access to the vault even if one Protector becomes inaccessible. If there is a need for more than two protectors, it is recommended to transfer the ownership of the vault to a multisig wallet.

#### Vault Operators

Alongside Protectors, the vault can also have operators—wallets that have the authority to manage the assets in the vault akin to the owner. For example, an owner may possess an NFT in an externally owned account (EOA) wallet like MetaMask and set two protectors using a cold wallet, like a Ledger, and a secondary wallet that hasn't been imported into MetaMask. This setup ensures that the owner can interact with the NFT without the risk of being phished, as any actual token transfer would fail without the approval of the protectors.

A real-world example can be a CEO who purchases two vaults—one for Marketing and another for Development. The CEO can appoint the CFO as a Protector, and the CTO and CMO as operators for the respective vaults.

While it is possible for an owner not to set any Protectors and manage the vault directly, this approach is not recommended due to potential security risks.

#### Asset Recovery and Beneficiary Management

The Cruna Vault provides a mechanism for asset recovery in case the owner loses access or passes away. The owner can designate beneficiaries and set a recovery quorum and expiration timeframe.

Before the expiry, the owner has to trigger a proof-of-life event to indicate they still retain access. If the event isn't triggered, a designated beneficiary can initiate the recovery process and suggest a recipient wallet.

Other beneficiaries can confirm the transfer or reject it. If rejected, they can suggest an alternate recipient. The protocol is designed to prevent blocking of the process by hostile beneficiaries.

This beneficiary management system enables orderly transfer of assets to successors in case of incapacity or demise of the vault owner. It provides individuals and entities a way to ensure business continuity and asset inheritance in a secure manner.


### 2. The Flexi Vault

The Flexi Vault is an application designed to securely store and protect assets (ERC20, ERC721, ERC1155). The ownership of the Flexi Vault is linked to the owning NFT, signifying that transferring the ownership of the NFT also transfers the ownership of the Flexi Vault.

Since the Cruna Vault is a ProtectedERC721, the Flexi Vault inherits its security features. When the owner of the NFT has designated a Protector, any asset movement from the Flexi Vault to external wallets or other vaults not owned by the same owner necessitates a signature from the Protector, enhancing the security of asset transfers.

On deployment, the Flexi Vault initiates a Trustee, a distinct NFT designed to manage smart contract wallets using [ERC6551](https://eips.ethereum.org/EIPS/eip-6551) bound accounts. Any tokenId of the Trustee is initially owned by the Flexi Vault and, by extension, by the Vault's owner.

The owner reserves the right to eject their Trustee at any moment, facilitating the transfer of an ID ownership from the Flexi Vault to the Cruna Vault's owner. This action can be reversed in the future, thereby reactivating the vault and resuming asset management.

### 3. Trustee, Smart Contracts, and Vault Migration

The Trustee, as an integral part of the Cruna Vault, is designed to offer flexibility in managing smart contract wallets. It can be ejected and re-injected into the vault, enabling migration between different versions of the vault. This feature is crucial considering that all smart contracts used in the Cruna Core Protocol are immutable, barring the exception of the ERC6551 bound account.

During the activation of the vault, users have the option to select either an immutable or an upgradeable account. The latter can be particularly beneficial if new asset standards are introduced in the future, ensuring the ability to receive these assets within the vault.

#### Vault Migration Process

The process of upgrading a Cruna Vault to a new version is straightforward, although it requires careful steps due to the immutable nature of smart contracts.

1. **Deployment of the New Contract**: The first step involves deploying the new contract for the upgraded Cruna Vault (V2).
2. **Eject the Trustee from the Old Vault**: The owner must then eject the Trustee from the current vault (V1). This action transfers the ownership of the Trustee ID from the Flexi Vault to the owner of the Cruna Vault.
3. **Re-Inject the Trustee into the New Vault**: The final step is to re-inject the ejected Trustee into the new vault (V2). This effectively transfers the management of the assets from the old vault to the new one.

Through this migration process, users can seamlessly transition to newer versions of the Cruna Vault, ensuring they can take advantage of new features and improved security measures while maintaining the control and security of their assets.

### Use Cases

- Consolidate all assets of a collection into a single Flexi Vault, allowing a seamless transfer of ownership without needing to move each asset individually. This offers significant improvements in security and user experience.

- Create asset bundles and list them for sale as a single NFT on popular marketplaces like OpenSea.

- Deposit vested assets into a Flexi Vault for scheduled distribution to investors, team members, etc. Note that for this to work, the asset must be capable of managing the vesting schedule. In a future version of the Cruna Core Protocol, a Flexi Distributor will be introduced to handle the vesting of any assets.

- Create a Flexi Vault for a DAO, allowing the DAO to manage its assets collectively.

### Future developments

As the Cruna Core Protocol continues to evolve, two noteworthy additions are currently in the pipeline: the Distributor Vault and the Inheritance Vault. Each of these vaults caters to specific needs, expanding the applications of the Cruna Core Protocol in the realms of asset management and security.

#### Distributor Vault

The Distributor Vault is a specialized vault designed to streamline the process of scheduled asset distribution. An entity can pre-load this vault with assets, which are then automatically distributed to the designated beneficiaries according to a predetermined schedule.

This functionality can be advantageous in numerous scenarios. For instance, a company wishing to distribute its governance tokens (ERC20) can purchase a Distributor Vault, fill it with the appropriate tokens, and set a vesting schedule. Once the NFT ownership of the Distributor Vault is given to an investor, the company no longer needs to actively manage token distribution. The tokens will be vested and delivered automatically as per the set schedule, providing the investor with an assurance of receiving their assets in a timely manner. This system is not only beneficial for investors, but it can also be employed for the scheduled distribution of tokens to employees, advisors, and other stakeholders.

## History

**1.4.1**

- Add support for receiving ERC777 in ERC6551Account

**1.4.0**

- Full refactor to manage the upgradeability of the vaults, despite being immutable
- Remove ERC7108, not really needed in this stage

**1.2.6**

- Integrate ClusteredERC721 to manage clusters inside the Cruna Vault
- Allow the user to choose between an immutable bound-account and an upgradeable one
- Renames OwnerNFT to Trustee
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

## Contributions

This project started from the collaboration between [Everdragons2](https://everdragons2.com), [Nduja Labs](https://ndujalabs.com) and [The Round Table](https://trt.gg).

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
