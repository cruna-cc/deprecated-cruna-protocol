#!/usr/bin/env node

const hre = require("hardhat");

async function main() {
  const contractPath = process.argv[2];
  if (!contractPath) {
    console.error("Usage: node compile-single.js <contract-path>");
    process.exit(1);
  }

  console.log(`Compiling ${contractPath}`);
  await hre.run("compile", {
    quiet: true,
    sources: [contractPath],
  });
  console.log("Compilation successful");
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
