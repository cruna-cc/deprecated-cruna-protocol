#!/usr/bin/env bash

skip=
if [[ "$2" == "localhost" ]]; then
  skip=true
fi

scripts/check-hardhat-console.js \
  && SKIP_CRYPTOENV=$skip TOKEN_URI=$3 npx hardhat run scripts/deploy-$1.js --network $2
