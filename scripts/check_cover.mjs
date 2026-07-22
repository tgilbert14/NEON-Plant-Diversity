#!/usr/bin/env node

import { createHash } from "node:crypto";
import { readFileSync, existsSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const html = readFileSync(resolve(root, "docs/index.html"), "utf8");
const ui = readFileSync(resolve(root, "ui.R"), "utf8");
const css = readFileSync(resolve(root, "www/plant.css"), "utf8");
let failed = false;

function fail(message) {
  failed = true;
  console.error(`FAIL: ${message}`);
}
function count(pattern, source = html) {
  return (source.match(pattern) || []).length;
}
function requireText(pattern, message, source = html) {
  if (!pattern.test(source)) fail(message);
}
function sha256(buffer) {
  return createHash("sha256").update(buffer).digest("hex");
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
requireText(/<html\s+lang="en">/i, "document language must be English");
requireText(/class="skip"[^>]+href="#main"/, "missing skip link to the poster");
requireText(/<nav\b[^>]+aria-label="NEON Explorer Suite"/, "suite route needs an accessible label");
requireText(/<link\s+rel="canonical"\s+href="https:\/\/tgilbert14\.github\.io\/NEON-Plant-Diversity\/">/i,
  "canonical URL is missing or incorrect");
requireText(/property="og:image:width" content="1200"/i, "Open Graph width must be 1200");
requireText(/property="og:image:height" content="630"/i, "Open Graph height must be 630");
requireText(/property="og:image:alt" content="[^"]+"/i, "Open Graph image needs alternative text");
requireText(/name="twitter:image:alt" content="[^"]+"/i, "Twitter image needs alternative text");
requireText(/<source media="\(max-width: 700px\)" srcset="assets\/cover-generated\/plant-nested-quadrat-hero-mobile-v1\.jpg">/,
  "mobile poster image source is missing");
requireText(/src="assets\/cover-generated\/plant-nested-quadrat-hero-v1\.jpg"/, "desktop poster image is missing");
requireText(/<img[^>]+alt="[^"]+"/, "poster image needs alternative text");
requireText(/How much can one square hold\?/i, "poster hook is missing");
requireText(/Explore plant communities from one square metre outward\./i, "poster promise is missing");
requireText(/Pick a place/i, "poster CTA must be contextual");
requireText(/Editorial illustration—not a field photograph or data record\./i, "poster must disclose the art/data boundary");
requireText(/nested survey grains/i, "cover must state the observation scope");
requireText(/not productivity, total landscape diversity, ecological health/i, "cover must state the primary claim boundary");
requireText(/DP1\.10058\.001/i, "cover must identify the source data product");
requireText(/Explore 46 places/i, "cover must identify the 46-place bundle scope");
if (count(/https:\/\/tgilbert14\.github\.io\/NEON-Driver-Cascade\//g) !== 1) {
  fail("poster face must contain exactly one Driver route");
}
for (const forbiddenPosterBlock of [/hero-facts/i, /splash-contract/i, /release receipt/i, /suite-app/i]) {
  if (forbiddenPosterBlock.test(html)) fail(`poster contains a retired report block: ${forbiddenPosterBlock}`);
}

requireText(/plant_diversity_poster\s*<-\s*function/, "in-app Living Poster component is missing", ui);
requireText(/How much can one square hold\?/i, "in-app poster hook diverges from Pages", ui);
requireText(/Explore plant communities from one square metre outward\./i, "in-app poster promise diverges from Pages", ui);
requireText(/href = "#site-picker-start"/, "in-app poster CTA must route to the picker", ui);
requireText(/id = "site-picker-start"[^\n]+tabindex = "-1"/, "in-app picker target must be focusable", ui);
requireText(/plant-nested-quadrat-hero-mobile-v1\.jpg/, "in-app poster needs a responsive mobile asset", ui);
if (count(/NEON-Driver-Cascade\//g, ui) !== 1) fail("in-app poster must contain exactly one Driver route");
requireText(/@media \(prefers-reduced-motion: reduce\)/, "poster CSS needs reduced-motion handling", css);
requireText(/@media \(forced-colors: active\)/, "poster CSS needs forced-colors handling", css);

for (const forbidden of [
  /fonts\.googleapis\.com/i, /fonts\.gstatic\.com/i, /cdnjs\.cloudflare\.com/i,
  /unpkg\.com/i, /jsdelivr\.net/i, /fetch\s*\(/i,
  /mode\s*:\s*["']no-cors["']/i, /(?:href|src)=["']http:\/\//i,
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

const imageAssets = [
  ["docs/assets/plant-nested-quadrat-hero-v1-source.png", 1774, 887, "77e73fedf5ab741763d9efa50bf3b876239707ee32d1e2bdceb767b38245e814"],
  ["docs/assets/plant-nested-quadrat-hero-mobile-v1-source.png", 941, 1672, "a729f710a1580f89fc8db000c738321db7af487ad9a759f71a0445d427856f01"],
  ["docs/assets/cover-generated/plant-nested-quadrat-hero-v1.jpg", 1774, 887, "6f150f3949082ecefa0d94055d9ac7ff5e36701d73debb1d03d2dc8c39314825"],
  ["docs/assets/cover-generated/plant-nested-quadrat-hero-mobile-v1.jpg", 941, 1672, "8856dbee5ba5883da18b75d68e5dafde8ea8f14707160e4cf3f2c2352d870d38"],
  ["docs/og-image.png", 1200, 630, "0c3c9262ec1ab046137dd082626b94dee775271be8c58f6f3287bee97e30c3cb"],
  ["www/assets/plant-nested-quadrat-hero-v1.jpg", 1774, 887, "6f150f3949082ecefa0d94055d9ac7ff5e36701d73debb1d03d2dc8c39314825"],
  ["www/assets/plant-nested-quadrat-hero-mobile-v1.jpg", 941, 1672, "8856dbee5ba5883da18b75d68e5dafde8ea8f14707160e4cf3f2c2352d870d38"],
];
for (const [file, expectedWidth, expectedHeight, expectedHash] of imageAssets) {
  try {
    const buffer = readFileSync(resolve(root, file));
    const [width, height] = imageDimensions(buffer);
    if (width !== expectedWidth || height !== expectedHeight) {
      fail(`${file} is ${width}x${height}; expected ${expectedWidth}x${expectedHeight}`);
    }
    const actualHash = sha256(buffer);
    if (actualHash !== expectedHash) fail(`${file} hash changed: ${actualHash}`);
  } catch (error) {
    fail(`${file}: ${error.message}`);
  }
}

const svgHash = sha256(readFileSync(resolve(root, "docs/assets/cover-generated/plant-social-card-v1.svg")));
if (svgHash !== "897063dc84b8f6660792fcfffcf36f59980934e4bf7e1a6c3d1ba544fe46d1a0") {
  fail(`social-card SVG hash changed: ${svgHash}`);
}

for (const match of html.matchAll(/<a\b[^>]*target="_blank"[^>]*>/gi)) {
  if (!/rel="[^"]*noopener[^"]*"/i.test(match[0])) fail("target=_blank link is missing rel=noopener");
}

if (failed) process.exit(1);
console.log("OK: Pages and in-app Living Poster, accessibility, claim, and image contracts passed.");
