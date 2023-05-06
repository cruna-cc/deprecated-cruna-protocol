#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const excludedFolderPath = path.resolve(__dirname, "../contracts");

// Recursively get all .sol files within a folder
function getSolidityFiles(folderPath) {
  const entries = fs.readdirSync(folderPath, {withFileTypes: true});

  const files = entries
    .filter((entry) => !entry.isDirectory())
    .map((entry) => path.join(folderPath, entry.name))
    .filter((file) => file.endsWith(".sol"));

  const folders = entries.filter((entry) => entry.isDirectory());

  for (const folder of folders) {
    files.push(...getSolidityFiles(path.join(folderPath, folder.name)));
  }

  return files.filter((file) => file.includes("/mocks"));
}

module.exports = getSolidityFiles(excludedFolderPath);
