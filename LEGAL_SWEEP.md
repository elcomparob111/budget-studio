# Budget Studio — Copyright & License Compliance Sweep

**Date:** July 9, 2026  
**Workspace:** `/Users/rob/Documents/Budget`  
**Scope:** Web PWA + iOS (SwiftUI) + CDN/SPM dependencies + brand assets  
**Method:** Inventory of `package.json`, CDN imports, `ios/project.yml` / `Package.resolved`, asset metadata, git history, UI/marketing copy. **No assets or code were deleted.**

---

## 1. All third-party packages and their licenses

### npm (`package.json`)

| Package | Declared in package.json? | License | Notes |
|---------|---------------------------|---------|-------|
| *(none)* | No runtime/devDependencies | — | App is vanilla JS. `npm start` uses `npx serve` (ephemeral CLI, not a project dependency). **No `package-lock.json` / `yarn.lock`.** |

### Web CDN (runtime)

| Asset | Source | Version pin | Upstream license (typical) | Where used |
|-------|--------|-------------|----------------------------|------------|
| `@supabase/supabase-js` | `https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm` | Major `@2` (floating) | **MIT** (Supabase) | `sync.js` dynamic `import()` |
| **Inter** font | Google Fonts CSS + `fonts.gstatic.com` files | weights 400–800 | **SIL Open Font License 1.1 (OFL)** for Inter; delivery also subject to **Google Fonts Terms of Service** | `index.html` `<link>`; `styles.css` `font-family: Inter, …` |

CSP / host configs explicitly allow these CDNs: `index.html` meta CSP, `netlify.toml`, `vercel.json`.

### iOS Swift Package Manager (`ios/project.yml` + `Package.resolved`)

Direct dependency:

| Package | URL | Resolved version | License |
|---------|-----|------------------|---------|
| **Supabase** (`supabase-swift`) | https://github.com/supabase/supabase-swift | **2.51.0** (`from: 2.5.0` in project.yml) | **MIT** |

Transitive pins from `ios/BudgetStudio.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`:

| Package | Resolved version | License (from checkout LICENSE*) |
|---------|------------------|----------------------------------|
| swift-asn1 (Apple) | 1.7.1 | **Apache-2.0** |
| swift-clocks (Point-Free) | 1.1.0 | **MIT** |
| swift-concurrency-extras (Point-Free) | 1.4.0 | **MIT** |
| swift-crypto (Apple) | 4.5.0 | **Apache-2.0** |
| swift-http-types (Apple) | 1.6.0 | **Apache-2.0** |
| xctest-dynamic-overlay (Point-Free) | 1.10.1 | **MIT** |

### Platform / system (not redistributed as project files)

| Item | Notes |
|------|--------|
| Apple SF Symbols / system rounded UI fonts | Used via SwiftUI `Image(systemName:)` and `.system(..., design: .rounded)` in `ios/BudgetStudio/Design/AppTheme.swift`. Subject to Apple platform terms; not vendored in-repo. |
| Vision / LocalAuthentication / Keychain | On-device Apple frameworks (receipt OCR, Face ID). |

### Repo / project license file

| Item | Status |
|------|--------|
| Root `LICENSE` / `LICENSE.md` | **MISSING** — no project license file found. |
| Third-party NOTICE / attribution file | **MISSING** — no `NOTICE`, `THIRD_PARTY_LICENSES`, or in-app OSS credits screen. |

---

## 2. Any risky licenses: GPL, AGPL, LGPL, unknown, no license

| Finding | Severity | Detail |
|---------|----------|--------|
| **No project LICENSE** | **High for distribution clarity** | App source/assets have **no declared license**. Default copyright remains with the author; redistributors/forks lack clear terms. |
| GPL / AGPL / LGPL | **None found** | No copyleft packages in npm (empty), CDN (Supabase MIT), or SPM tree (MIT / Apache-2.0 only). |
| Unknown npm licenses | **N/A** | No declared npm dependencies. |
| **CDN floating major** (`@supabase/supabase-js@2`) | Low–Medium ops | Not a “risky license,” but version is not fully pinned; license remains MIT across v2, yet supply-chain/reproducibility is weaker than a lockfile. |
| **AI dog logo provenance** | **Medium** (see §3) | Not a software license issue; commercial/IP clarity for the brand mark is incomplete. |
| Google Fonts CDN | Low–Medium compliance hygiene | Inter itself is OFL; using Google’s CDN also implicates Google Fonts ToS (and historically raised privacy discussions). Self-hosting OFL files is the cleaner launch pattern. |

**No GPL/AGPL/LGPL infection risk identified in current dependency trees.**

---

## 3. All image/icon/font assets and where they came from

| Asset | Path(s) | Provenance | Notes / risk |
|-------|---------|------------|--------------|
| **Dog app icon (AI-stylized)** | `icons/icon-192.png`, `icons/icon-512.png`, `icons/icon-1024.png`; iOS `AppLogo.imageset/logo.png` (= same bytes as `icon-192.png`); iOS `AppIcon.appiconset/icon-1024.png` (related export, different hash) | **AI-generated / unknown commercial provenance** | Git commit `d7b4b79` message: *“Add AI-stylized dog logo as the Budget Studio app icon”* — *“Uses the family dogs as a friendly illustrated icon”*; Co-authored-by Cursor. No artist signature, stock receipt, or generator license file in repo. PNG metadata: no useful creator tEXt; some EXIF dimension tags only. Visual style is polished illustration consistent with generative tools. **Flag: treat as unknown provenance for App Store / commercial branding until rights are documented.** |
| **Favicon (geometric)** | `favicon.svg` | **Appears original / project-authored** | Simple dark rounded square + blue dashed ring. No third-party marks. Currently **not** the primary favicon in `index.html` (PWA uses dog PNGs). |
| **Inter** | Loaded from Google Fonts in `index.html` | **rsms Inter — SIL OFL 1.1**; served via **Google Fonts** | OFL allows embedding/bundling with attribution norms; Google Fonts ToS governs CDN use. Prefer self-host `woff2` under OFL for launch. |
| **iOS system fonts / SF Symbols** | SwiftUI throughout | Apple platform | Not project-owned font files. |
| **`outputs/` screenshots & xlsx** | `outputs/interactive-budget-sheet-20260708/*` | App UI captures / personal workbook | **Gitignored** (`outputs/` in `.gitignore`) — not shipped in git; listed for completeness. |
| **`public/`** | `public/_headers` only | N/A | No image assets. |
| **Agent skill art guidance** | `.agents/skills/swiftui-design/` | Internal Cursor skill | Not a shipped product asset. |

**Dog logo — honest assessment:** Origin is **AI-stylized from family dog photos** per commit message, but **generator, prompt, and license grant are not recorded** in-repo. For launch, assume **unknown provenance** until you archive: (1) source photos ownership, (2) which tool generated the art, (3) that tool’s commercial terms at generation time, (4) whether any stock/reference art was used.

---

## 4. Any files that look copied or too similar to existing apps

| Area | Assessment |
|------|------------|
| Web UI (`index.html`, `styles.css`, `app.js`) | Custom vanilla PWA. Comment in CSS: *“iOS-matched web UI.”* Layout patterns resemble generic Apple HIG / personal-finance dashboards (metric cards, tabs, rings) but **no evidence of wholesale copy from Mint, YNAB, Monarch, Copilot, etc.** |
| iOS SwiftUI | Native rebuild described in README; uses project design tokens + system components. Not a clone of a known App Store budget UI at the code level. |
| `sync.js` / `security.js` | Project-specific Supabase + XSS/sanitization helpers. Comments describe architecture, not “copied from …”. |
| Charts | Inline SVG in `app.js` — simple custom drawing, not Chart.js/D3 vendored. |
| Legal pages | Short plain-language drafts; generic structure common to many apps, **not** a paste of a known SaaS ToS. |
| Name “Budget Studio” | Descriptive; no collision analysis performed against trademarks (out of scope of file sweep — recommend a quick USPTO/App Store search before commercial branding). |

**No file was flagged as a clear copy of another product’s proprietary source.** Similarity is at the *category UX* level only.

---

## 5. Any text that sounds copied from another product

| Text | Location | Assessment |
|------|----------|------------|
| “Personal budget **command center**” | `index.html` meta description; `manifest.json` | Marketing cliché; not distinctive IP of a single competitor. Low risk; optional rephrase. |
| “Guided setup with starter budgets based on your income” | `index.html` / iOS setup | Generic feature copy. |
| Privacy / Terms disclaimers (“not financial advice”, “as is”, limitation of liability) | `privacy.html`, `terms.html` | Standard legal tropes; appear **original short drafts**, not a known vendor’s ToS. Still need counsel review for commercial launch (`SECURITY.md` already notes this). |
| Auth / security user strings | `security.js`, iOS `SupabaseService` | Generic UX (“Check your internet…”, rate-limit messaging). |
| Competitor brand names in product UI | — | **None found** (no Mint/YNAB/etc. in shipped copy). |

**No high-confidence “stolen marketing copy” findings.**

---

## 6. What needs to be replaced before launch

**Do not delete yet — document and replace/clarify:**

1. **Add a root `LICENSE`** (and decide OSS vs proprietary). Until then, redistribution rights are unclear.  
2. **Dog logo / App Icon** — replace **or** document AI tool + commercial rights + photo ownership; keep current files until replacement is ready. Highest brand/IP uncertainty.  
3. **Self-host Inter (OFL)** or switch to a fully owned/system stack; stop relying solely on Google Fonts CDN if you want cleaner ToS/privacy posture. Keep OFL attribution if bundling.  
4. **Pin `@supabase/supabase-js`** to an exact version (or vendor the ESM file) and record MIT attribution in a `THIRD_PARTY_NOTICES` (or Settings → Licenses).  
5. **iOS OSS attribution** — list supabase-swift + transitive MIT/Apache packages in App Store privacy/credits or an in-app Licenses screen (Apple often expects this for included OSS).  
6. **Counsel review** of `privacy.html` / `terms.html` before any paid/commercial positioning (already flagged in `SECURITY.md`).  
7. **Optional:** Trademark clearance for “Budget Studio” / bundle id `com.budgetstudio.app`.  
8. **Optional:** Soften “command center” marketing if you want more distinctive voice (not a legal blocker).

**Scripts added for ongoing checks:** `npm run license:check`, `npm run security:audit` (see `package.json`).

---

## 7. A final risk rating: Low, Medium, or High

### **Medium**

**Why not Low:** Missing project `LICENSE`; primary brand mark is **AI-stylized with undocumented generator/commercial terms**; Google Fonts CDN + floating Supabase CDN major; no third-party notices file; legal pages are DIY.

**Why not High:** No GPL/AGPL/LGPL dependencies; SPM and Supabase JS are permissive (MIT/Apache-2.0); no clear evidence of copied proprietary app code or competitor trademarks in UI; favicon geometry looks original; privacy/terms read as original drafts.

**Launch blocker priority:** (1) license the repo or explicitly mark proprietary, (2) clear or replace the dog logo, (3) add third-party attribution + prefer self-hosted Inter.

---

*Sweep performed without removing assets or rewriting application code. Findings are documentation only.*
