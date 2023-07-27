const fs = require("fs-extra");
const path = require("path");
const {deployContract} = require("../test/helpers");

async function main() {
  const ABIs = {
    when: new Date().toISOString(),
    contracts: {},
  };

  function abi(name, folder, rename) {
    let source = path.resolve(__dirname, `../artifacts/${folder ? folder + "/" : ""}${name}.sol/${name}.json`);
    let json = require(source);
    ABIs.contracts[rename || name] = json.abi;
  }
  abi("CrunaClusterFactory", "contracts/factory");
  abi("CrunaVault", "contracts/implementation");
  abi("ERC6551Registry", "contracts/ERC6551");
  abi("ERC6551Account", "contracts/ERC6551");
  abi("ERC6551AccountUpgradeable", "contracts/ERC6551");
  abi("ERC6551AccountProxy", "contracts/ERC6551");
  abi("FlexiVault", "contracts/vaults");
  abi("TokenUtils", "contracts/utils");

  abi("ERC20", "@openzeppelin/contracts/token/ERC20");
  abi("ERC721", "@openzeppelin/contracts/token/ERC721");
  abi("ERC721Enumerable", "@openzeppelin/contracts/token/ERC721/extensions");
  abi("ERC1155", "@openzeppelin/contracts/token/ERC1155");

  // for dev only
  abi("USDCoin", "contracts/mocks/fake-tokens");
  abi("TetherUSD", "contracts/mocks/fake-tokens");
  abi("Bulls", "contracts/mocks/fake-tokens");
  abi("Bulls", "contracts/mocks/fake-tokens");
  abi("FatBelly", "contracts/mocks/fake-tokens");
  abi("Particle", "contracts/mocks/fake-tokens");
  abi("StupidMonk", "contracts/mocks/fake-tokens");
  abi("UselessWeapons", "contracts/mocks/fake-tokens");

  await fs.writeFile(path.resolve(__dirname, "../export/ABIs.json"), JSON.stringify(ABIs, null, 2));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
