# Cruna Protocol

A protocol to manage application NFTs, born from the collaboration between [Everdragons2](https://everdragons2.com), [Nduja Labs](https://ndujalabs.com) and [The Round Table](https://trt.gg).

## History

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
