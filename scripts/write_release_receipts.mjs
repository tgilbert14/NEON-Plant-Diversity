#!/usr/bin/env node

// Produce public, content-addressed release receipts. The runtime receipt covers
// every byte deployed to Connect except itself plus the source-of-truth manifest
// and verifier contracts (which bind R, repository, and exact package pins). The
// cover receipt covers the Pages HTML, social image, and local visual assets.
// Post-deploy smoke compares these tokens so an old-but-healthy revision cannot pass.

import { createHash } from "node:crypto";
import { existsSync, readdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { dirname, join, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";
import { mkdirSync } from "node:fs";

const codeRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const dataRoot = resolve(process.env.PDE_RUNTIME_DATA_ROOT || codeRoot);
const canonicalRuntimeReceipt = resolve(codeRoot, "www", "runtime-receipt.txt");
const canonicalCoverReceipt = resolve(codeRoot, "docs", "cover-receipt.txt");
const runtimeOut = resolve(process.env.PDE_RUNTIME_RECEIPT_OUT || canonicalRuntimeReceipt);
const coverOut = resolve(process.env.PDE_COVER_RECEIPT_OUT || canonicalCoverReceipt);
const checkOnly = process.argv.includes("--check");
const skipCover = process.env.PDE_SKIP_COVER_RECEIPT === "1";

const posix = (path) => path.split(sep).join("/");
const sha256 = (bytes) => createHash("sha256").update(bytes).digest("hex");

function filesUnder(root, predicate = () => true) {
  if (!existsSync(root)) return [];
  const output = [];
  for (const name of readdirSync(root).sort()) {
    const path = join(root, name);
    const stat = statSync(path);
    if (stat.isDirectory()) output.push(...filesUnder(path, predicate));
    else if (stat.isFile() && predicate(path)) output.push(path);
  }
  return output;
}

function runtimeFiles() {
  const files = ["global.R", "ui.R", "server.R", "scripts/write_manifest.R",
    "scripts/verify_bundle.R"].map((name) => join(codeRoot, name));
  files.push(...filesUnder(join(codeRoot, "R"), (path) => path.endsWith(".R")));
  files.push(...filesUnder(join(codeRoot, "www"), (path) => {
    const resolved = resolve(path);
    return resolved !== canonicalRuntimeReceipt && resolved !== runtimeOut;
  }));
  files.push(...filesUnder(join(dataRoot, "data"), (path) => {
    const rel = posix(relative(join(dataRoot, "data"), path));
    return path.endsWith(".rds") && (
      !rel.includes("/") || rel.startsWith("sites/") || rel.startsWith("env/") ||
      rel.startsWith("expected/") || rel === "authority/plants_lookup.rds"
    );
  }));
  files.push(...filesUnder(join(dataRoot, "data-sample"), (path) => path.endsWith(".rds")));
  return [...new Set(files.map((path) => resolve(path)))].filter(existsSync).sort();
}

function virtualRuntimePath(path) {
  const resolved = resolve(path);
  if (resolved.startsWith(`${dataRoot}${sep}`)) return posix(relative(dataRoot, resolved));
  return posix(relative(codeRoot, resolved));
}

function coverFiles() {
  const docs = join(codeRoot, "docs");
  return [join(docs, "index.html"), join(docs, "og-image.png"),
    ...filesUnder(join(docs, "assets"))]
    .map((path) => resolve(path)).filter((path) => existsSync(path) &&
      path !== canonicalCoverReceipt && path !== coverOut).sort();
}

function receipt(files, virtualPath, inventoryOut = "") {
  const entries = files.map((path) => ({ path, virtual: virtualPath(path) }))
    .sort((a, b) => a.virtual < b.virtual ? -1 : a.virtual > b.virtual ? 1 : 0);
  const inventory = entries.map(({ path, virtual }) =>
    `${virtual}\0${sha256(readFileSync(path))}\n`).join("");
  if (inventoryOut) writeFileSync(resolve(inventoryOut), inventory, "utf8");
  return `sha256:${sha256(Buffer.from(inventory, "utf8"))}\n`;
}

function publish(path, value, label) {
  if (checkOnly) {
    const current = existsSync(path) ? readFileSync(path, "utf8") : "";
    if (current !== value) throw new Error(`${label} is stale; run node scripts/write_release_receipts.mjs`);
    process.stdout.write(`OK: ${label} ${value}`);
    return;
  }
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, value, "utf8");
  process.stdout.write(`WROTE: ${label} ${value}`);
}

const runtime = runtimeFiles();
if (!runtime.length) throw new Error("runtime receipt inventory is empty");
publish(runtimeOut, receipt(runtime, virtualRuntimePath, process.env.PDE_RUNTIME_INVENTORY_OUT), "runtime release receipt");

if (!skipCover) {
  const cover = coverFiles();
  if (!cover.length) throw new Error("cover receipt inventory is empty");
  publish(coverOut, receipt(cover, (path) => posix(relative(join(codeRoot, "docs"), path))), "cover release receipt");
}
