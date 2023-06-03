const fs = require("fs-extra");
const path = require("path");

async function main() {
  const ABIs = {
    when: new Date().toISOString(),
    contracts: {},
  };

  function abi(name, folder, rename) {
    let source = path.resolve(__dirname, `../artifacts/contracts/${folder ? folder + "/" : ""}${name}.sol/${name}.json`);
    let json = require(source);
    ABIs.contracts[rename || name] = json.abi;
  }
  abi("CrunaVault", "implementation");
  abi("ERC6551Registry", "bound-account");
  abi("ERC6551Account", "bound-account");
  abi("ERC6551AccountUpgradeable", "bound-account");
  abi("ERC6551AccountProxy", "bound-account");
  abi("TransparentVault", "vaults");
  abi("TokenUtils", "utils");

  await fs.writeFile(path.resolve(__dirname, "../export/ABIs.json"), JSON.stringify(ABIs, null, 2));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
