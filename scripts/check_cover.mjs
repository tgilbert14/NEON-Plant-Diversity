#!/usr/bin/env node

import { readFileSync, existsSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const coverPath = resolve(root, "docs/index.html");
const html = readFileSync(coverPath, "utf8");
let failed = false;

function fail(message) {
  failed = true;
  console.error(`FAIL: ${message}`);
}
function count(pattern) {
  return (html.match(pattern) || []).length;
}
function requireText(pattern, message) {
  if (!pattern.test(html)) fail(message);
}
function imageDimensions(buffer) {
  const png = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  if (buffer.subarray(0, 8).equals(png)) {
    return [buffer.readUInt32BE(16), buffer.readUInt32BE(20)];
  }
  if (buffer[0] === 0xff && buffer[1] === 0xd8) {
    let offset = 2;
    while (offset + 9 < buffer.length) {
      if (buffer[offset] !== 0xff) { offset += 1; continue; }
      const marker = buffer[offset + 1];
      if (marker === 0xd8 || marker === 0xd9) { offset += 2; continue; }
      const length = buffer.readUInt16BE(offset + 2);
      if ([0xc0, 0xc1, 0xc2, 0xc3, 0xc5, 0xc6, 0xc7, 0xc9, 0xca, 0xcb, 0xcd, 0xce, 0xcf].includes(marker)) {
        return [buffer.readUInt16BE(offset + 7), buffer.readUInt16BE(offset + 5)];
      }
      if (length < 2) break;
      offset += 2 + length;
    }
  }
  throw new Error("unsupported or malformed image");
}

if (count(/<h1\b/gi) !== 1) fail("cover must contain exactly one h1");
if (count(/<main\b/gi) !== 1) fail("cover must contain exactly one main landmark");
requireText(/<html\s+lang=["']en["']/i, "document language must be English");
requireText(/class=["']skip-link["'][^>]+href=["']#main["']/i, "missing skip link to #main");
requireText(/<nav\b[^>]+aria-label=["'][^"']+["']/i, "primary navigation needs an accessible label");
requireText(/aria-label=["']NEON Explorer Suite companions["']/i, "suite navigation needs an accessible label");
requireText(/aria-current=["']page["']/i, "current suite application must be identified");
requireText(/<link\s+rel=["']canonical["']\s+href=["']https:\/\/tgilbert14\.github\.io\/NEON-Plant-Diversity\/["']>/i,
  "canonical URL is missing or incorrect");
requireText(/property=["']og:image:width["']\s+content=["']1200["']/i, "Open Graph width must be 1200");
requireText(/property=["']og:image:height["']\s+content=["']630["']/i, "Open Graph height must be 630");
requireText(/property=["']og:image:alt["']\s+content=["'][^"']+["']/i, "Open Graph image needs alternative text");
requireText(/name=["']twitter:image:alt["']\s+content=["'][^"']+["']/i, "Twitter image needs alternative text");
requireText(/What this app can tell you/i, "cover must state what the app can answer");
requireText(/What it cannot settle/i, "cover must state what the app cannot answer");
requireText(/Driver Cascade/i, "cover must explain its suite/Driver role");
requireText(/Release receipt/i, "cover must expose a data/release receipt");
requireText(/DP1\.10058\.001/i, "cover must identify the source data product");
requireText(/46[\s\S]{0,100}(bundled|terrestrial) sites/i, "cover must identify the 46-site bundle scope");

const suiteUrls = [
  "NEON-Driver-Cascade", "NEON-Small-Mammal-Tracker-App",
  "NEON-Plant-Phenology-Explorer", "NEON-Plant-Diversity",
  "NEON-Vegetation-Structure-Explorer", "NEON-Ground-Beetle-Tracker",
  "NEON-Mosquito-Pulse", "NEON-Breeding-Birds",
  "NEON-WaterChemistry-Analyte-Viewer-App", "NEON-My-Little-Inverts",
];
for (const slug of suiteUrls) {
  if (!html.includes(`https://tgilbert14.github.io/${slug}/`)) fail(`missing suite URL: ${slug}`);
}

for (const forbidden of [
  /fonts\.googleapis\.com/i, /fonts\.gstatic\.com/i, /cdnjs\.cloudflare\.com/i,
  /unpkg\.com/i, /jsdelivr\.net/i, /fetch\s*\(/i,
  /mode\s*:\s*["']no-cors["']/i, /http:\/\//i,
]) {
  if (forbidden.test(html)) fail(`forbidden external runtime or insecure pattern: ${forbidden}`);
}

for (const match of html.matchAll(/<(?:img|source)\b[^>]+(?:src|srcset)=["']([^"']+)["'][^>]*>/gi)) {
  const relative = match[1].split(/\s+/)[0];
  if (/^(?:https?:|data:|\/\/)/i.test(relative)) continue;
  const path = resolve(root, "docs", relative.split(/[?#]/)[0]);
  if (!existsSync(path)) fail(`referenced cover image is missing: ${relative}`);
  if (/^<img\b/i.test(match[0]) && !/\balt=["'][^"']*["']/i.test(match[0])) {
    fail(`cover image lacks alt text: ${relative}`);
  }
}

try {
  const social = readFileSync(resolve(root, "docs/og-image.png"));
  const [width, height] = imageDimensions(social);
  if (width !== 1200 || height !== 630) fail(`docs/og-image.png is ${width}x${height}, expected 1200x630`);
} catch (error) {
  fail(`docs/og-image.png: ${error.message}`);
}

for (const match of html.matchAll(/<a\b[^>]*target=["']_blank["'][^>]*>/gi)) {
  if (!/rel=["'][^"']*noopener[^"']*["']/i.test(match[0]))
    fail("target=_blank link is missing rel=noopener");
}

if (failed) process.exit(1);
console.log("OK: cover accessibility, claims, suite links, local assets, and social metadata passed.");
