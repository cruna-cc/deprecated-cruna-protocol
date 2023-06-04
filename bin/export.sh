#!/usr/bin/env bash
# must be run from the root

npm run clean
NODE_ENV=test npx hardhat compile

node scripts/exportABIs.js
