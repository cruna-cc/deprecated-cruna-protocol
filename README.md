# Cruna Core Protocol

## The protocol

The Cruna Core Protocol establishes a unique hierarchy between an NFT and one or more applications, so that the owner of the NFT is also the owner of the correspondent profile of the application.

While the owning token functions as a conventional NFT, the owned app focuses on providing tangible utility. In the Cruna MVP, the inaugural application takes the form of a safe-box.

### The protector

Since the owning token carries significant responsibility, this protocol adds extra-security to the ERC721 standard, introducing ProtectedERC721 contracts, i.e., NFTs that can disable approvals and can add a protector wallet that must initialize relevant transactions (like transfers).

To enhance security, certain limitations have been implemented.

**Interaction with Marketplaces:**

- The NFT cannot be approved for everyone, as this is a common avenue for phishing attacks.
- Before using the protected NFT (for example, before depositing in a vault), the NFT should be made not-approvable. Even if not mandatory, the Cruna dashboard will push the user to do so.

**Ownership Transfer:**

- While a Protected NFT can be transferred by default, the owner has the option to designate one or more protector wallets, i.e., wallets that must initiate a transfer.
- When a protector is assigned, any transfer process must be initiated by the protector and subsequently confirmed by the owner. This added layer of security ensures that even in the event of phishing, scammers cannot transfer the NFT without the protector's involvement. And, in case the protector is scammed, still the owner must confirm the transfer.

### The Transparent Vault

A Transparent Vault is a an application designed to store and safeguard assets (ERC20, ERC721, ERC1155). Its ownership is derived from the owning NFT, meaning that transferring the NFT's ownership will also transfer the ownership of the Transparent Vault.

The Transparent Vault inherits security features from its owning NFT if the owning NFT is a ProtectedERC721. If the NFT's owner has designated a protector, any movement within the Transparent Vault must be initiated by the protector and confirmed by the owner. This added security layer helps prevent scammers from transferring or withdrawing assets in the event of phishing. Typically, a protector is a wallet stored in a cold wallet, reserved for crucial operations and not used for daily transactions.

Assets can be deposited into the Transparent Vault by the NFT's owner or other wallets. To prevent abuse, the owner can establish rules to permit deposits from everyone, specific wallets, or exclusively from the owner. It's also possible to implement a confirmation-based system requiring the owner's approval for deposits not originating from whitelisted wallets or the owner themselves.

Asset transfers between Protectors can be executed by the owner, even if an initiator is set, as long as the destination NFT is owned by the same wallet. If the destination NFT has a different owner, the initiator must be utilized.

The simple concept of a Transparent Vault dramatically enhances the security of an NFT collection.

### Use Cases

- Consolidate all assets of a collection into a single Transparent Vault, allowing a seamless transfer of ownership without needing to move each asset individually. This offers significant improvements in security and user experience.

- Create asset bundles and list them for sale as a single NFT on popular marketplaces like OpenSea.

- Deposit vested assets into a Transparent Vault for scheduled distribution to investors, team members, etc. Note that for this to work, the asset must be capable of managing the vesting schedule. In a future version of the Cruna Core Protocol, a Transparent Distributor will be introduced to handle the vesting of any assets.

### Contract ownership

The Cruna Core Protocol lays the foundation for any NFT collection to incorporate a Transparent Vault. CoolProject has the distinction of being the inaugural project to execute this protocol.

Given that any project utilizing the protocol could theoretically introduce harmful functions, the Cruna DAO will conduct audits on the associated contracts. Following this review, they will then determine whether the project should be granted access to be managed within the Cruna dashboard. Projects that have not been listed and choose to implement the protocol are required to construct their own management dashboard.

## Other elements of the Cruna protocol

- [ERC721Locked](./LOCKED_NFT.md)
- [ERC721Subordinate](./DOMINANT_SUBORDINATE.md)
- [NFTOwned](./NFT_OWNED.md)
- [ERC721Lockable](./LOCKABLE_NFT.md)

In particular, it uses a slightly modified version of [EIP-6551](https://eips.ethereum.org/EIPS/eip-6551) contained in the [bound-account](./bound-account) folder, taken from [the ERC-6551 reference implementation](https://github.com/erc6551/reference).

## History

**1.2.0**

- Park the Transparent Vault contracts, as they are not used in the current version of the protocol
- Introduce an airdroppable version of the vault, using ERC6551 to handle the assets
- Add in the lockable folder the ERC721Lockable contracts, taken from [ndujaLabs/erc721lockable](https://github.com/ndujalabs/erc721lockable) repo, for completeness
- Make the CrunaSafebox not upgradeable for improved trust, allowing migration to V2 in the future

**1.0.3**

- Remove some unused variables from TransparentSafeBox
- Modify TransparentSafeBox so that TransparentVaultEnumerable can extend it
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

This project has born from the collaboration between [CoolProject](https://everdragons2.com), [Nduja Labs](https://ndujalabs.com) and [The Round Table](https://trt.gg).

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
