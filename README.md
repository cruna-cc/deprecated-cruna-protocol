# Cruna Core Protocol

A platform that implements the [DS-protocol](https://github.com/cruna-cc/DS-protocol) to manage NaaA (NFT-as-an-app), born from the collaboration between [Everdragons2](https://everdragons2.com), [Nduja Labs](https://ndujalabs.com) and [The Round Table](https://trt.gg).

## The protocol

The Cruna Core Protocol establishes a unique hierarchy between two distinct NFTs – the Protector and the Protected – operating on EVM-compatible blockchains to facilitate the management of utility-driven NFTs. The Protected NFT, subordinate in nature, does not possess the capability to alter token ownership; rather, it derives its ownership from the dominant Protector NFT. Simply put, the wallet owning the Protector NFT inherently owns the corresponding Protected NFT.

While the Protector NFT functions as a conventional NFT, complete with rarity distribution and other standard attributes, the Protected NFT diverges by focusing on providing tangible utility. In the Cruna MVP, the inaugural utility NFT takes the form of a Transparent Vault.

### The protector

The Protector NFT carries significant responsibility, as its ownership can imply control over hundreds of additional assets. To enhance security, certain limitations have been implemented.

**Interaction with Marketplaces:**

- The NFT cannot be approved for everyone, as this is a common avenue for phishing attacks.
- By default, the NFT is not set for approval; it must be explicitly made approvable for listing on marketplaces.

**Ownership Transfer:**

- While a Protector NFT can be transferred by default, the owner has the option to designate an initiator wallet.
- When an initiator is assigned, any transfer process must be initiated by the initiator and subsequently confirmed by the owner. This added layer of security ensures that even in the event of phishing, scammers cannot transfer the NFT without the initiator's involvement.

### The protected Transparent Vault

A Transparent Vault is a protected NFT designed to store and safeguard assets (ERC20, ERC721, ERC1155). Its ownership is derived from the associated Protector NFT, meaning that transferring the Protector NFT's ownership will also transfer the ownership of the Transparent Vault.

The Transparent Vault inherits security features from its Protector NFT. If the Protector's owner has designated an initiator, any movement within the Transparent Vault must be initiated by the initiator and confirmed by the owner. This added security layer helps prevent scammers from transferring or withdrawing assets in the event of phishing. Typically, an initiator is a wallet stored in a cold wallet, reserved for crucial operations and not used for daily transactions.

Assets can be deposited into the Transparent Vault by the Protector's owner or other wallets. To prevent abuse, the owner can establish rules to permit deposits from everyone, specific wallets, or exclusively from the owner. It's also possible to implement a confirmation-based system requiring the owner's approval for deposits not originating from whitelisted wallets or the owner themselves.

Asset transfers between Protectors can be executed by the owner, even if an initiator is set, as long as the destination Protector is owned by the same individual. If the destination Protector has a different owner, the initiator must be utilized.

The simple concept of a Transparent Vault dramatically enhances the security of an NFT collection.

### Use Cases

- Consolidate all assets of a collection into a single Transparent Vault, allowing a seamless transfer of ownership without needing to move each asset individually. This offers significant improvements in security and user experience.

- Create asset bundles and list them for sale as a single NFT on popular marketplaces like OpenSea.

- Deposit vested assets into a Transparent Vault for scheduled distribution to investors, team members, etc. Note that for this to work, the asset must be capable of managing the vesting schedule. In a future version of the Cruna Core Protocol, a Transparent Distributor will be introduced to handle the vesting of any assets.

### Contract ownership

The Cruna Core Protocol establishes a framework that enables any NFT collection to integrate a Transparent Vault. Everdragons2 is the first project to implement this protocol.

Contracts will be deployed and upgraded by the Cruna DAO, but ownership will be transferred to the Everdragons2 DAO. This arrangement allows the Everdragons2 project to receive royalties from sales, manage parameters, tokenURI, and more, while Cruna maintains the ability to upgrade contracts as needed.

This separation of functions between the project launching the Protector and the DAO is essential to prevent hostile projects from upgrading the Protector contract in a way that scams users.

**Implementation Process**

A project wishing to deploy a new Protector contract must create a proposal by opening a PR in the /projects folder of this repo. The Cruna DAO will audit the proposal, and if approved, the project and DAO will determine when to deploy the contracts for the Protector and Protected. Although it is theoretically possible to associate multiple Protected NFTs with a single Protector, initially, only one Protected NFT per Protector will be supported.

**Upgrades**

When a new feature is ready for deployment, the Cruna DAO will open an improvement proposal. If approved, the DAO will upgrade the Protector, Protected, or both contracts as needed – for instance, if a bug is found or a vulnerability is discovered.

### Costs

Implementing the Cruna Core Protocol necessitates a sophisticated UI to manage both Protector and Protected NFTs. Cruna, in collaboration with ndujaLabs and The Round Table, will develop this UI, which will be freely accessible to all projects looking to integrate the Cruna Core Protocol. To offset costs, a 5% royalty fee will be applied to the initial sale of each Protector NFT.

### Initial NFT Sales

To streamline the process for projects, Cruna will develop an app designed to manage the initial sales of Protector NFTs. This white-label app will be provided to projects free of charge and will evolve over time, incorporating features requested by projects and those associated with new Protected NFTs released through the protocol.

## History

**0.1.5**

- Moving to @cruna/ds-protocol
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
