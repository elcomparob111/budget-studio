#!/usr/bin/env node
/**
 * security:audit — npm audit when a lockfile exists; always runs security:scan.
 * With no package-lock.json (vanilla Budget Studio), audit is skipped with a note.
 */
import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const lockPath = join(root, "package-lock.json");

function run(cmd, args) {
  const result = spawnSync(cmd, args, { cwd: root, stdio: "inherit", shell: false });
  if (result.error) {
    console.error(result.error.message);
    return 1;
  }
  return result.status ?? 1;
}

console.log("== Budget Studio security:audit ==\n");

let code = 0;

if (existsSync(lockPath)) {
  console.log("package-lock.json found — running npm audit --audit-level=moderate\n");
  const auditCode = run("npm", ["audit", "--audit-level=moderate"]);
  if (auditCode !== 0) code = auditCode;
} else {
  console.log("No package-lock.json — skipping npm audit (no installed npm dependency tree).");
  console.log("CDN runtime deps (@supabase/supabase-js, Google Fonts) are not covered by npm audit.\n");
}

console.log("Running security:scan (secret / footgun checks)…\n");
const scanCode = run("npm", ["run", "security:scan"]);
if (scanCode !== 0) code = scanCode;

if (code === 0) {
  console.log("\nsecurity:audit completed successfully.");
} else {
  console.error("\nsecurity:audit failed.");
}

process.exit(code);
