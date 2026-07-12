# Growth Plan — Budget Studio → top-charting envelope budgeting app

**Date:** 2026-07-12 · Synthesized from a code/UI audit and market research (sources at bottom).
**Positioning thesis:** Envelope-method budgeting app for people priced out of YNAB ($109/yr) and couples who budget together — with a warm mascot brand voice on TikTok and a trust-first icon on the stores.

---

## 1. Code efficiency fixes (ranked by impact/effort; none touch budget math)

| # | Fix | Where |
|---|-----|-------|
| 1 | Trend chart: one pass grouping transactions by month instead of 12× `getMonthSummary()` per render | `app.js:1372-1383` |
| 2 | Render only the active tab; render-on-switch | `app.js:1230-1234`, `switchTab` at `app.js:816` |
| 3 | iOS: bind `store.monthSummary` / `categorySpending` once per `body` (currently recomputed 6+× per render) | `BudgetStore.swift:31,34`, `OverviewView.swift` |
| 4 | `getMonthSummary`: single-pass category map instead of per-category filters | `app.js:1548-1557` |
| 5 | Hoist `Intl.NumberFormat` instances to module constants | `app.js:2591-2608` |
| 6 | Vendor supabase-js locally + SW-precache (kills CDN latency, fixes offline, also closes audit item S5 pin-CDN) | `sync.js:67`, `sw.js` |
| 7 | Self-host 2-weight Inter WOFF2 subset (also closes audit items I3/P3) | `index.html:20-22` |
| 8 | SW: cache-first for versioned assets; `index.html` fallback only for navigations | `sw.js:46-67` |
| 9 | iOS: persist state to a file (off main actor), not UserDefaults | `BudgetStore.swift:438-442` |
| 10 | iOS: split UI-transient state out of the mega-ObservableObject (or adopt `@Observable`) | `BudgetStore.swift:6-18` |
| 11 | Coalesce the 3-4 startup renders into one post-auth render | `app.js:494,538,559` |

Already good: 900ms debounced cloud pushes on both platforms, no listener leaks, CSS card transform for mobile tables.

## 2. UI/UX fixes (ranked)

1. **Dark-mode charts are broken** — SVGs hardcode light hex; use `var(--text)`/`var(--muted)` (`app.js:1364-1416`).
2. **Undoable delete** — delete is one tap, instant, no undo (`app.js:656-663`). Add 5s undo toast.
3. **Amount-first quick add** — web add-expense is ~7 interactions (`index.html:153-183`). Bottom sheet, keypad, amount first, smart defaults; iOS: move Amount above Date.
4. **≥44px touch targets** (currently 32-36px icon buttons).
5. **Tappable month label → month/year picker + "Today" chip** (picker exists but is hidden, `index.html:43`).
6. **Red/green semantic color on money chips** and negative "Plan left" (`app.js:1260-1262`).
7. **Real empty states**: new-user CTA vs "clear filters" (`app.js:1448`).
8. **SVG icon set on web** — replace ◐ ☰ ▦ ⚙ glyphs/emoji (`index.html:53-63`).
9. **Auth polish**: persistent password-rule helper text; fix `minlength=1` vs 8-char policy (`index.html:455`).
10. **Header = safe-to-spend hero number**, not "Welcome!/Today".
11. **Dashboard hierarchy**: one hero metric, demote the rest (Copilot/Monarch pattern).
12. **Sync `theme-color` meta with dark mode.**

## 3. Feature roadmap (download-impact × feasibility, no bank aggregation required)

| Priority | Feature | Why (market evidence) |
|---|---|---|
| P0 | **Shared/couples budgets** (Supabase realtime; invite by link) | Monarch's growth wedge; Buddy/Goodbudget prove manual+shared works; every shared budget imports a second user = built-in referral loop |
| P0 | **Safe-to-spend hero number** | PocketGuard's entire hook; envelopes already compute it |
| P1 | **Recurring expenses + bill reminders** (push notifications) | Rocket Money's hook minus detection; "bill reminder" is a searched keyword |
| P1 | **Quick-entry everywhere**: iOS widgets, Apple Watch, Siri shortcut | Entry friction is THE churn driver for manual apps; Piere calls widgets its hottest 2026 drop |
| P2 | **Savings goals / debt payoff targets** | YNAB Targets / EveryDollar staple |
| P2 | **CSV import/export, multi-currency** | Searched keywords; bridge until bank sync |
| P3 | **AI insights/chat on manual data** ("what did I overspend on?") | Cleo proves AI voice sells; needs cost control |
| Later | Bank sync (Plaid) | Table stakes for paid leaders but big compliance/cost jump — only after paying users exist |
| Skip | Roundups, credit score, cash advances | Require banking partners |

## 4. Name + logo

**Verdict on the dog:** keep the dog as the *brand mascot and TikTok voice*, not the app icon. Evidence: no top finance app has an animal-mascot icon (trust cues dominate; bold minimal icons drive ~20% of installs), but Cleo built ~$300M ARR on a personality-led marketing voice. Best of both: mascot in content + onboarding, clean icon on the store. The current AI-generated logo must be replaced anyway (provenance risk, `legal/AI_ASSETS.md`).

**Name:** "Budget Studio" is generic, unownable, and keyword-invisible. Winning patterns: warm persona names (Cleo, Buddy, Albert, Piere) or benefit compounds (PocketGuard, Goodbudget, Rocket Money). Candidates (all need trademark + App Store search checks, `legal/TRADEMARK.md`):

| Name | Angle | Risk |
|---|---|---|
| **Tuck** (top pick) | Dog's name AND the money verb ("tuck it away"); envelope-fold icon; "Tuck: Envelope Budget" fits 30-char title | Short names are contested; check class 36/42 |
| **Penny** | Classic dog name + literal money; "Penny: Budget & Envelopes" | Prior Penny finance apps existed (defunct — verify) |
| **Biscuit** | Dog treat + warm; memorable TikTok mascot | Weak money signal |
| **Snug** | Money safe + cozy | Abstract |
| **Stash-adjacent envelope names** (e.g. "Stuffed" for cash-stuffing) | Native to the TikTok genre | Stash (investing) proximity; tone |

Store listing pattern: `Name: Budget Planner & Envelopes` / subtitle `Expense tracker for couples` — long-tail keywords (envelope budget, budget app for couples, manual expense tracker, budget planner no ads) where incumbents don't compete.

## 5. Go-to-market (what actually gets downloads in 2026)

ASO converts demand; it doesn't create it. The evidenced playbook for a new indie finance app:

1. **Short-form video**: envelope/"cash stuffing" is a native TikTok genre — a digital envelope app with a dog mascot has an unfair content angle. Cleo and Emma built their funnels here.
2. **"YNAB alternative" positioning on Reddit** — r/ynab price-hike anger and the Mint migration built Monarch and Actual Budget. Price at ~$29-49/yr against YNAB's $109.
3. **Couples invite loop** — shared budgets are an organic install mechanic; make "invite your partner" a first-run step.
4. **ASO long-tails** (above) + Product Hunt for the web/PWA launch spike.

**Reality check:** "most downloaded" in finance means beating Cleo/Rocket Money — VC-funded, bank-connected. The winnable game as a solo dev: **own the envelope/manual/couples niche** (Buddy: 5M+ downloads, indie, Stockholm — proof it's a real business), then expand. Sequence: fix UI top-5 → ship couples budgets + safe-to-spend → rebrand (name/icon) → TestFlight → App Store with long-tail ASO → TikTok + Reddit flywheel.

---

*Research sources: Sensor Tower Q3-2025 finance rankings; Sacra/Sifted (Cleo ~$300M ARR); CNBC (Monarch $75M raise); NerdWallet/Engadget/Forbes 2026 roundups; Buddy/Piere App Store listings; AppTweak/AppFollow ASO guides; DesignRush/ASOMobile icon-trend reports. Code audit: internal, 2026-07-12.*
