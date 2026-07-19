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
const plantStyles = readFileSync("www/plant.css", "utf8");

function cssBlocks(source, headerPattern) {
  const blocks = [];
  for (const match of source.matchAll(headerPattern)) {
    const open = source.indexOf("{", match.index);
    let depth = 0;
    let close = -1;
    for (let index = open; index < source.length; index += 1) {
      if (source[index] === "{") depth += 1;
      if (source[index] === "}") depth -= 1;
      if (depth === 0) { close = index; break; }
    }
    if (open < 0 || close < 0) throw new Error(`unbalanced CSS block after ${match[0]}`);
    blocks.push(source.slice(open + 1, close));
  }
  return blocks;
}
if (!/id\s*=\s*["']appStatus["']/.test(ui) || !/data-app-ready/.test(ui)) {
  throw new Error("ui.R must expose the appStatus semantic readiness element");
}
if (!/dataset\.appReady\s*=\s*["']true["']/.test(app)) {
  throw new Error("www/app.js must promote the semantic readiness state after connection");
}
if (!/jQuery\(document\)\.on\(\s*["']shiny:connected["']\s*,\s*smtHandleShinyConnected\s*\)/.test(app)) {
  throw new Error("www/app.js must subscribe to Shiny's jQuery lifecycle event for readiness and deep links");
}
if (!/jQuery\(document\)\.on\(\s*["']shiny:disconnected["']\s*,\s*smtHandleShinyDisconnected\s*\)/.test(app) ||
    !/function\s+smtHandleShinyDisconnected\s*\([^)]*\)\s*\{[^}]*dataset\.appReady\s*=\s*["']false["'][^}]*dataset\.siteReady\s*=\s*["']false["']/s.test(app)) {
  throw new Error("www/app.js must revoke both semantic readiness markers when Shiny disconnects");
}
const mobileHeaderBlocks = cssBlocks(
  plantStyles,
  /@media\s*\(max-width:\s*640px\)\s*\{/g,
).filter((block) => /\.hero-title\s*\{/.test(block));
if (mobileHeaderBlocks.length !== 1) {
  throw new Error(`expected exactly one Plant mobile-header media block, found ${mobileHeaderBlocks.length}`);
}
const mobileHeaderStyles = mobileHeaderBlocks[0];
const mobileHeaderContract = [
  /\.hero-title\s*\{[^}]*flex-wrap:\s*wrap[^}]*align-items:\s*flex-start/s,
  /\.hero-receipt\s*\{[^}]*flex:\s*1\s+0\s+100%[^}]*background:\s*var\(--paper\)/s,
  /\.hero-change,\s*\.hero-report\s*\{[^}]*flex:\s*1\s+1\s+calc\(50%\s*-\s*4px\)[^}]*min-height:\s*44px/s,
  /\.hero-change,\s*\.hero-change:hover\s*\{[^}]*color:\s*var\(--pine2\)/s,
  /\.hero-report,\s*\.hero-report:hover\s*\{[^}]*color:\s*var\(--sky2\)/s,
];
if (!mobileHeaderContract.every((contract) => contract.test(mobileHeaderStyles))) {
  throw new Error("plant.css must own the final mobile header cascade: full-row receipt, equal touch-sized actions, and accessible change-site color");
}
if (!/\.hero-title\s*\{[^}]*color:\s*var\(--pine2\)/s.test(plantStyles) ||
    !/\.hero-change\s*\{[^}]*color:\s*var\(--pine2\)/s.test(styles) ||
    !/\.hero-change:hover\s*\{[^}]*color:\s*var\(--pine2\)/s.test(styles) ||
    !/\.hero-report:hover\s*\{[^}]*color:\s*var\(--pine2\)/s.test(styles)) {
  throw new Error("loaded-site title and action states must retain AA contrast in the final cascade");
}
if (/\.hero-title\s*\{[^}]*flex-wrap:\s*wrap/s.test(styles)) {
  throw new Error("styles.css must not shadow the Plant-specific mobile header contract");
}
const compactTopBarBlocks = cssBlocks(
  styles,
  /@media\s*\(max-width:\s*360px\)\s*\{/g,
).filter((block) => /\.top-bar-actions\s*\{/.test(block));
const compactTopBarContract = [
  /\.top-bar-actions\s*\{[^}]*width:\s*100%[^}]*display:\s*grid[^}]*grid-template-columns:\s*minmax\(0,\s*1fr\)\s+44px\s+auto/s,
  /\.app-status\s*\{[^}]*width:\s*100%[^}]*max-width:\s*none[^}]*justify-content:\s*center/s,
  /\.top-bar-actions\s+\.tb-help\s*\{[^}]*width:\s*44px[^}]*min-width:\s*44px/s,
];
if (compactTopBarBlocks.length !== 1 ||
    !compactTopBarContract.every((contract) => contract.test(compactTopBarBlocks[0]))) {
  throw new Error("the 320px top bar must give readiness a full grid track beside fixed-size controls");
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

console.log(`OK: ${seen} handlers, semantic readiness, final-cascade mobile site header, and deferred Plotly event wiring passed.`);
