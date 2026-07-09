# Production Audit — Budget Studio

**Date:** July 9, 2026  
**Roles applied:** Lead Security Engineer, Lead Software Architect, Lead DevOps, General Counsel (documentation only — not a law firm opinion)  
**Workspace:** `/Users/rob/Documents/Budget`  
**Architecture verified:** Static PWA (GitHub Pages) + Supabase Auth/DB + native iOS. **No custom Node API.**

**Score convention:** All scores are **health scores** (0–100). **100 = best / lowest risk.**

---

## 1. Executive Summary

Budget Studio has a **credible family-app / early-beta security foundation**: anon-only clients, RLS SQL ready, XSS/sanitization defenses, privacy/terms drafts, and (as of this pack) proprietary licensing plus third-party attribution docs. It is **not** yet production-ready for commercial scale or acquisition diligence without operator dashboard work, logo/trademark clearance, counsel-reviewed legal copy, real security headers hosting, monitoring/DR, and self-serve account deletion.

Honest bottom line: ship to family and careful private beta after Supabase RLS/Auth checklist; treat public paid launch and “millions of users” as a **roadmap**, not a checkbox.

| Score | Value | One-line read |
|-------|------:|---------------|
| Security | **68** | Strong client hygiene; server Auth/RLS/headers/monitoring incomplete |
| IP (health) | **62** | Proprietary LICENSE added; AI logo + trademark gaps remain |
| Privacy | **58** | Clear policy + export/delete row; no full Auth deletion / counsel / DPA rigor |
| Code Quality | **64** | Focused vanilla + SwiftUI; large `app.js`, limited automated coverage |
| Production Readiness | **52** | Family-ready path; not million-user prod |
| Business Readiness | **55** | Docs/legal pack strong; entity, counsel, App Store, DR still open |

**Overall weighted readiness (informal):** ~**58 / 100** for commercial release; ~**75 / 100** for private family use after operator Supabase steps.

---

## 2. Security Score — **68 / 100**

### Strengths

- Anon/publishable key only; `service_role` guard in `sync.js`; `npm run security:scan` clean
- RLS policies well-designed in `supabase/rls.sql` (owner must still apply/verify live)
- `escapeHtml`, payload sanitization, import caps, ownership asserts, safe logger, SW same-origin-only cache
- Security unit tests passing (`tests/security.test.js`)
- Optional Netlify/Vercel/`_headers` CSP with `frame-ancestors 'none'`

### Issues

| ID | Issue | Why it matters | Severity | Safest fix | Status |
|----|-------|----------------|----------|------------|--------|
| S1 | RLS/Auth dashboard settings not verified in this audit | Without live RLS, anon key + PostgREST is catastrophic | **Critical** | Run `rls.sql`; verify policies; enable email confirm + rate limits | **Deferred** (operator) |
| S2 | GitHub Pages cannot set CSP/`frame-ancestors`/HSTS headers | Clickjacking + weaker XSS defense-in-depth | **High** | Host on Cloudflare/Netlify/Vercel using existing configs | **Deferred** |
| S3 | JWT in client storage (Supabase default) | XSS ⇒ account takeover | **High** | Maintain CSP + escaping; consider future BFF/HttpOnly if threat model rises | **Mitigated** in client; residual risk |
| S4 | Client auth lockout bypassable | Credential stuffing | **Medium** | Supabase Auth rate limits + CAPTCHA | **Deferred** (operator) |
| S5 | Floating CDN `@supabase/supabase-js@2` | Supply-chain / unexpected breakage | **Medium** | Pin exact version on jsDelivr | **Deferred** |
| S6 | No SIEM / auth anomaly monitoring | Slow incident detection at scale | **Medium** | Log drain + alerts | **Deferred** |
| S7 | Full Auth user deletion not self-serve | Stale accounts; privacy rights incomplete | **Medium** | Edge Function (service role server-side only) | **Deferred** |
| S8 | Face ID stores password in Keychain (optional) | Device compromise / shared device | **Low** | Document; allow disable (exists) | **Accepted** with disclosure |

---

## 3. IP Risk Score (health) — **62 / 100**

Higher = safer IP posture for commercial / acquisition.

### Strengths

- Proprietary **All Rights Reserved** `LICENSE` (2026 Roberto Munoz / Budget Studio)
- `legal/COPYRIGHT.md`, `THIRD_PARTY_LICENSES.md`, `AI_ASSETS.md`, `TRADEMARK.md`
- No GPL/AGPL/LGPL in CDN/SPM trees
- No clear copied competitor source found ([`LEGAL_SWEEP.md`](../LEGAL_SWEEP.md))

### Issues

| ID | Issue | Why it matters | Severity | Safest fix | Status |
|----|-------|----------------|----------|------------|--------|
| I1 | Dog logo AI provenance unknown | Brand/App Store/diligence risk | **High** | Document tool+ToS or replace ([`legal/AI_ASSETS.md`](../legal/AI_ASSETS.md)) | **Documented**; asset kept |
| I2 | No trademark clearance for “Budget Studio” | Rename risk post-launch | **Medium** | USPTO/App Store search + counsel | **Deferred** |
| I3 | Google Fonts CDN for Inter | ToS + privacy hygiene; OFL itself OK | **Low–Medium** | Self-host OFL woff2 | **Deferred** (recommended) |
| I4 | No in-app OSS credits screen | App Store expectation | **Low** | Settings → Licenses | **Deferred** |
| I5 | DIY Privacy/Terms | Enforceability / diligence | **Medium** | Counsel review | **Deferred** |
| I6 | Was missing LICENSE | Redistribution ambiguity | **High** (pre-fix) | Proprietary LICENSE | **Implemented** |

---

## 4. Privacy Score — **58 / 100**

### Strengths

- Honest privacy.html: Supabase named, no bank aggregation, export + delete cloud row
- Minimal data map (email + budget JSON)
- Contact email for requests

### Issues

| ID | Issue | Why it matters | Severity | Safest fix | Status |
|----|-------|----------------|----------|------------|--------|
| P1 | Auth user not deleted by in-app flow | Incomplete erasure | **Medium** | Privileged deletion EF + UI | **Deferred** |
| P2 | Legal pages not counsel-reviewed | Regulatory/commercial risk | **Medium** | Counsel before paid launch | **Deferred** |
| P3 | Google Fonts may expose IP to Google | Privacy disclosure gap | **Low–Medium** | Self-host fonts; update policy | **Deferred** |
| P4 | Backup retention of deleted users undefined | GDPR-style expectations | **Medium** | Document PITR retention | **Deferred** |
| P5 | No formal request SLA | User rights process | **Low** | 30-day response policy | **Deferred** |
| P6 | Operator is individual | Fine if disclosed; update when entity forms | **Low** | Update privacy when incorporating | **Accepted** |

See [`legal/PRIVACY_CHECKLIST.md`](../legal/PRIVACY_CHECKLIST.md).

---

## 5. Code Quality Score — **64 / 100**

### Strengths

- Clear separation: `security.js` / `sync.js` / `app.js`; iOS services/views
- Security tests for critical helpers
- Sanitization and limits reduce footguns
- Small dependency surface (good for maintainability)

### Issues

| ID | Issue | Why it matters | Severity | Safest fix | Status |
|----|-------|----------------|----------|------------|--------|
| C1 | Monolithic `app.js` (~90KB) | Harder review/test at scale | **Medium** | Gradual module split (no behavior change) | **Deferred** |
| C2 | Limited automated tests (security helpers only) | Regressions in budget math/UI | **Medium** | Add calculator/pure-function tests | **Deferred** |
| C3 | Dual clients (web + iOS) can drift | Sync/schema bugs | **Medium** | Shared schema doc + checklist on change | **Mitigated** via `docs/API.md` |
| C4 | No error reporting (Sentry etc.) | Blind production failures | **Medium** | Add privacy-safe crash reporting later | **Deferred** |
| C5 | JSON-in-Postgres blob | Flexible but harder querying/migrations | **Low** | Accept for v1; version `state` | **Accepted** |

---

## 6. Production Readiness Score — **52 / 100**

Honest for “millions of users / acquired startup”: a static SPA on GitHub Pages + one Supabase project is a **foundation**, not hyperscale prod.

### Strengths

- Deploy simplicity; HTTPS Pages; reproducible static assets
- Hosting header configs ready for upgrade path
- Launch + release checklists exist

### Issues

| ID | Issue | Why it matters | Severity | Safest fix | Status |
|----|-------|----------------|----------|------------|--------|
| R1 | No verified prod Auth/RLS in audit | Ship blocker | **Critical** | Operator checklist | **Deferred** |
| R2 | No monitoring/on-call | Outages unnoticed | **High** | Uptime + Supabase alerts | **Deferred** |
| R3 | DR/PITR not documented as tested | Data loss | **High** | Enable backups; restore drill | **Deferred** |
| R4 | Pages header limitations | Security at edge | **High** | Move static host | **Deferred** |
| R5 | No CI gate on main | Regressions | **Medium** | GitHub Action: test+scan | **Deferred** |
| R6 | Scale limits unknown (jsonb size, Auth QPS) | Melts under growth | **Medium** | Quotas + paid plan + load test | **Deferred** |
| R7 | SW cache discipline | Stale clients | **Low** | Bump only on asset change (policy documented) | **Accepted** |

---

## 7. Business Readiness Score — **55 / 100**

### Strengths

- Legal/docs pack for diligence narrative
- Clear ownership story (proprietary)
- Privacy/terms + contact path
- iOS project structure / bundle id present
- Roadmap distinguishes family vs scale

### Issues

| ID | Issue | Why it matters | Severity | Safest fix | Status |
|----|-------|----------------|----------|------------|--------|
| B1 | No counsel-reviewed contracts | Acquisition/commercial risk | **High** | Engage counsel | **Deferred** |
| B2 | Trademark uncleared | Brand risk | **Medium** | Search + file if appropriate | **Deferred** |
| B3 | Logo provenance | Brand asset cloud | **High** | Clear or replace | **Deferred** |
| B4 | No company entity called out | Contracting/DPA | **Medium** | Form entity when commercializing | **Deferred** |
| B5 | App Store listing not done | Distribution | **Medium** | TestFlight path in roadmap | **Deferred** |
| B6 | Support/ops process informal | Customer trust | **Medium** | Support mailbox SLA | **Deferred** |
| B7 | Docs/legal pack incomplete before audit | Diligence gaps | **Medium** | This pack | **Implemented** |

---

## Architecture confirmation

| Claim | Verified |
|-------|----------|
| Static PWA on GitHub Pages | Yes (`index.html`, `sw.js`, live URL in docs) |
| Supabase Auth + DB | Yes (`sync.js`, `supabase/rls.sql`, anon config) |
| Native iOS | Yes (`ios/BudgetStudio`, SPM Supabase) |
| Custom Node API | **No** |

---

## Changes implemented in this audit pack

- Added `legal/*` (LICENSE, COPYRIGHT, AI_ASSETS, THIRD_PARTY_LICENSES, TRADEMARK, COMPLIANCE/PRIVACY/RELEASE checklists)
- Added root proprietary `LICENSE`
- Added `docs/*` (ARCHITECTURE, SECURITY, API, DEPLOYMENT, ROADMAP, PRODUCTION_AUDIT)
- Root `SECURITY.md` → pointer to `docs/SECURITY.md`
- README cross-links (privacy, terms, docs, legal)
- `.gitignore` secret/env hardening
- `package.json` `license` field; license-check aware of LICENSE
- `LEGAL_SWEEP.md` updated to reference legal pack
- **Not changed:** budget math, auth UX flows, dog logo files, `sw.js` (docs-only)

---

## What the owner must still do

1. Run Supabase RLS + Auth settings ([`LAUNCH_CHECKLIST.md`](../LAUNCH_CHECKLIST.md))
2. Clear or replace dog logo provenance ([`legal/AI_ASSETS.md`](../legal/AI_ASSETS.md))
3. Trademark search ([`legal/TRADEMARK.md`](../legal/TRADEMARK.md))
4. Counsel review of Privacy/Terms
5. Prefer real CSP host before broad public launch
6. Plan Edge Function for full account deletion
7. Enable backups + monitoring before paid users
8. TestFlight when iOS is release-candidate

---

*This audit is practical engineering and compliance hygiene documentation. It is not a penetration test, SOC 2 report, or attorney-client privileged legal opinion.*
