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
const server = readFileSync("server.R", "utf8");
const styles = readFileSync("www/styles.css", "utf8");
if (!/id\s*=\s*["']appStatus["']/.test(ui) || !/data-app-ready/.test(ui)) {
  throw new Error("ui.R must expose the appStatus semantic readiness element");
}
if (!/dataset\.appReady\s*=\s*["']true["']/.test(app)) {
  throw new Error("www/app.js must promote the semantic readiness state after connection");
}
if (!/jQuery\(document\)\.on\(\s*["']shiny:connected["']\s*,\s*smtHandleShinyConnected\s*\)/.test(app)) {
  throw new Error("www/app.js must subscribe to Shiny's jQuery lifecycle event for readiness and deep links");
}
if (!/\.hero-title\s*\{[^}]*flex-wrap:\s*wrap/s.test(styles) ||
    !/\.hero-change,\s*\.hero-report\s*\{[^}]*min-height:\s*44px/s.test(styles)) {
  throw new Error("the loaded-site header must stack its receipt and keep both actions touch-sized on mobile");
}
if (!server.includes('observeEvent(input[["plotly_click-hillSrc"]], {')) {
  throw new Error("the lazy Hill plot must defer event_data() until an actual Plotly input arrives");
}
const hillEventReads = server.match(
  /plotly::event_data\(\s*["']plotly_click["']\s*,\s*source\s*=\s*["']hillSrc["']\s*\)/g,
) || [];
if (hillEventReads.length !== 1) {
  throw new Error(`expected one deferred hillSrc event_data() read, found ${hillEventReads.length}`);
}

console.log(`OK: ${seen} handlers, semantic readiness, mobile site header, and deferred Plotly event wiring passed.`);
