#!/usr/bin/env bash
# must be run from the root

rm -rf cache
rm -rf artifacts
npx hardhat compile

node scripts/exportABIs.js

cp export/ABIs.json ../sales-app/src/config/.
cp export/deployed.json ../sales-app/src/config/.
