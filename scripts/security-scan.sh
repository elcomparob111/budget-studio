#!/usr/bin/env bash
# Lightweight secret / footgun scan for Budget Studio (no npm deps required).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail=0

echo "== Security scan =="

# Look for assigned secrets (not documentation that warns about them).
if rg -n --glob '!ios/build/**' --glob '!**/SourcePackages/**' --glob '!node_modules/**' --glob '!SECURITY.md' --glob '!scripts/**' \
  -e 'service_role["'"'"']?\s*[:=]' \
  -e 'SUPABASE_SERVICE_ROLE\s*=' \
  -e 'BEGIN RSA PRIVATE KEY' \
  -e 'aws_secret_access_key\s*=' \
  -e 'sk_live_[0-9A-Za-z]+' \
  .; then
  echo "FAIL: possible secret material assignment found"
  fail=1
else
  echo "OK: no service_role / private key assignments in app sources"
fi

# Client config files must only export anon/publishable keys.
for cfg in sync-config.js ios/BudgetStudio/Services/SupabaseService.swift; do
  if [[ -f "$cfg" ]] && rg -n 'service_role["'"'"']?\s*[:=]|SUPABASE_SERVICE_ROLE\s*=' "$cfg"; then
    echo "FAIL: service_role key assignment in $cfg"
    fail=1
  fi
done
echo "OK: client configs have no service_role key assignment"

if ! rg -n 'anonKey' sync-config.js >/dev/null; then
  echo "FAIL: sync-config.js missing anonKey field"
  fail=1
else
  echo "OK: sync-config.js exposes anonKey only"
fi

if [[ -f package-lock.json ]]; then
  if command -v npm >/dev/null 2>&1; then
    echo "Running npm audit..."
    npm audit --omit=dev || true
  fi
else
  echo "OK: no npm lockfile — skip npm audit (vanilla JS app)"
fi

if [[ "$fail" -ne 0 ]]; then
  echo "Security scan failed."
  exit 1
fi
echo "Security scan passed."
