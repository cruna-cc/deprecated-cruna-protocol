#!/usr/bin/env bash
# must be run from the root

npm run clean
NODE_ENV=test npx hardhat compile

node scripts/exportABIs.js
cp export/ABIs.json ../cruna-dashboard/src/config/.
cp export/deployed.json ../cruna-dashboard/src/config/.
