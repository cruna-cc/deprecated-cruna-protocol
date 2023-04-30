#!/usr/bin/env node

const consoleLogAlert = require("./scripts/consoleLogAlert");

try {
  consoleLogAlert();
} catch (e) {
  console.log(e.message);
  process.exit(1);
}
