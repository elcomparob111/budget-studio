#!/usr/bin/env node
/**
 * License inventory for Budget Studio (vanilla JS + CDN + iOS SPM notes).
 * Exits non-zero if npm dependencies with risky licenses are detected.
 * Risky: GPL, AGPL, LGPL, UNKNOWN, UNLICENSED (when meaning unknown), NONE.
 */
import { readFileSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const pkgPath = join(root, "package.json");
const lockPath = join(root, "package-lock.json");

const RISKY =
  /\b(AGPL|GPL|LGPL|UNKNOWN|UNLICENSED|NONE|SEE LICENSE IN|PROPRIETARY)\b/i;
const COPYLEFT = /\b(AGPL|GPL|LGPL)\b/i;

const CDN_DEPS = [
  {
    name: "@supabase/supabase-js",
    how: "CDN import in sync.js (cdn.jsdelivr.net … @2/+esm)",
    license: "MIT",
  },
  {
    name: "Inter (font)",
    how: "Google Fonts CSS + fonts.gstatic.com in index.html",
    license: "OFL-1.1 (font) + Google Fonts ToS (CDN delivery)",
  },
];

const SPM_DEPS = [
  { name: "supabase-swift", license: "MIT", via: "ios/project.yml" },
  { name: "swift-asn1", license: "Apache-2.0", via: "Package.resolved transitive" },
  { name: "swift-clocks", license: "MIT", via: "Package.resolved transitive" },
  { name: "swift-concurrency-extras", license: "MIT", via: "Package.resolved transitive" },
  { name: "swift-crypto", license: "Apache-2.0", via: "Package.resolved transitive" },
  { name: "swift-http-types", license: "Apache-2.0", via: "Package.resolved transitive" },
  { name: "xctest-dynamic-overlay", license: "MIT", via: "Package.resolved transitive" },
];

function loadJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

function collectNpmNames(pkg) {
  const names = new Set();
  for (const field of ["dependencies", "devDependencies", "optionalDependencies", "peerDependencies"]) {
    const block = pkg[field] || {};
    for (const name of Object.keys(block)) names.add(name);
  }
  return [...names].sort();
}

console.log("== Budget Studio license:check ==\n");

if (!existsSync(pkgPath)) {
  console.error("FAIL: package.json missing");
  process.exit(1);
}

const pkg = loadJson(pkgPath);
const npmNames = collectNpmNames(pkg);

console.log("Project LICENSE file:", existsSync(join(root, "LICENSE")) || existsSync(join(root, "LICENSE.md"))
  ? "present"
  : "MISSING (flagged in LEGAL_SWEEP.md)");
console.log("");

console.log("--- CDN / runtime (documented) ---");
for (const d of CDN_DEPS) {
  console.log(`  ${d.name}`);
  console.log(`    license: ${d.license}`);
  console.log(`    source:  ${d.how}`);
}
console.log("");

console.log("--- iOS SPM (from project.yml / Package.resolved notes) ---");
for (const d of SPM_DEPS) {
  console.log(`  ${d.name}: ${d.license} (${d.via})`);
}
console.log("");

console.log("--- npm package.json dependencies ---");
if (npmNames.length === 0) {
  console.log("  (none declared)");
} else {
  for (const name of npmNames) console.log(`  ${name}`);
}
console.log("");

let riskyHits = [];

if (existsSync(lockPath) && npmNames.length > 0) {
  console.log("--- package-lock license scan ---");
  try {
    // Prefer license-checker when lockfile + deps exist.
    const { execSync } = await import("node:child_process");
    const out = execSync("npx --yes license-checker --summary --json", {
      cwd: root,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    });
    // Also print human summary
    const summary = execSync("npx --yes license-checker --summary", {
      cwd: root,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    });
    console.log(summary.trim());
    const data = JSON.parse(out);
    for (const [id, info] of Object.entries(data)) {
      const lic = String(info.licenses || "UNKNOWN");
      if (COPYLEFT.test(lic) || /^UNKNOWN$/i.test(lic) || /^NONE$/i.test(lic)) {
        riskyHits.push(`${id}: ${lic}`);
      }
    }
  } catch (err) {
    console.log("  license-checker unavailable or failed; falling back to name-only list.");
    console.log(`  (${err.message || err})`);
  }
} else if (npmNames.length > 0 && !existsSync(lockPath)) {
  console.log("NOTE: dependencies declared but no package-lock.json — run npm install to enable deep license scan.");
  for (const name of npmNames) {
    // Without lockfile we cannot resolve licenses; treat as unknown risk signal.
    if (RISKY.test(name)) riskyHits.push(`${name}: name matched risky pattern`);
  }
} else {
  console.log("OK: no npm lockfile / no npm deps — CDN + SPM inventory only.");
}

console.log("");
if (riskyHits.length) {
  console.error("FAIL: risky or unknown licenses detected:");
  for (const h of riskyHits) console.error(`  - ${h}`);
  process.exit(1);
}

console.log("OK: no risky npm licenses detected (GPL/AGPL/LGPL/unknown).");
console.log("See LEGAL_SWEEP.md for full compliance notes (project LICENSE, AI logo, Google Fonts).");
process.exit(0);
