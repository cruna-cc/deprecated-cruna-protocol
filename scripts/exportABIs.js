const fs = require("fs-extra");
const path = require("path");

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
  abi("CrunaVault", "contracts/implementation");
  abi("ERC6551Registry", "contracts/bound-account");
  abi("ERC6551Account", "contracts/bound-account");
  abi("ERC6551AccountUpgradeable", "contracts/bound-account");
  abi("ERC6551AccountProxy", "contracts/bound-account");
  abi("FlexiVault", "contracts/vaults");
  abi("TokenUtils", "contracts/utils");

  abi("ERC20", "@openzeppelin/contracts/token/ERC20");
  abi("ERC721", "@openzeppelin/contracts/token/ERC721");
  abi("ERC1155", "@openzeppelin/contracts/token/ERC1155");

  await fs.writeFile(path.resolve(__dirname, "../export/ABIs.json"), JSON.stringify(ABIs, null, 2));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
