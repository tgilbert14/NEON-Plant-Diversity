#!/usr/bin/env node

import { readFileSync } from "node:fs";

const files = ["www/app.js", "www/pincards.js"];
const handlerPattern = /Shiny\.addCustomMessageHandler\(\s*["'][^"']+["']\s*,\s*function\s*\(([^)]*)\)/g;
const invalid = [];
let seen = 0;

for (const file of files) {
  const source = readFileSync(file, "utf8");
  for (const match of source.matchAll(handlerPattern)) {
    seen += 1;
    const parameters = match[1]
      .split(",")
      .map((value) => value.trim())
      .filter(Boolean);
    if (parameters.length !== 1) invalid.push(`${file}: ${match[0]}`);
  }
}

if (seen !== 6) {
  throw new Error(`expected exactly 6 Shiny custom message handlers, found ${seen}`);
}
if (invalid.length) {
  throw new Error(
    `every Shiny custom message handler must accept exactly one payload argument:\n${invalid.join("\n")}`,
  );
}

const ui = readFileSync("ui.R", "utf8");
const app = readFileSync("www/app.js", "utf8");
if (!/id\s*=\s*["']appStatus["']/.test(ui) || !/data-app-ready/.test(ui)) {
  throw new Error("ui.R must expose the appStatus semantic readiness element");
}
if (!/dataset\.appReady\s*=\s*["']true["']/.test(app)) {
  throw new Error("www/app.js must promote the semantic readiness state after connection");
}

console.log(`OK: ${seen} handlers have one payload and the semantic readiness contract exists.`);
