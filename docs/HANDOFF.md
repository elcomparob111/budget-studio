# Handoff — Budget Studio

**Pinned:** July 25, 2026  
**Branch / tip:** `main`  
**Owner preference:** product is **good for day-to-day use**. Next agent picks from **Recommended next** below.

Read [`AGENTS.md`](../AGENTS.md) first, then this file. Do not re-litigate shipped P0 work unless fixing a bug.

---

## Just shipped (Jul 25)

| Area | Status | Notes |
|------|--------|--------|
| Home richness (web + iOS) | Done | Under Check left: payday countdown, over-plan / on-watch line, Recent (5 txs), Goals peek (2). Order: hero → Coming up → Recent → Goals → Where it went. SW **v70**. |
| Web Check-left Home parity | Done | Check left hero + wash, check ring, In/Out, month stepper, Month plan, Needs/Wants/Savings expand. |
| iOS Check-left redesign (prior) | Done | `410f1f8d` — Home/Activity/Savings/Settings polish. |

### Paths to know

- Web: `app.js`, `styles.css`, `index.html`, `sw.js` (`budget-studio-v70`)
- iOS Home: `ios/BudgetStudio/Views/OverviewView.swift`
- Live: https://elcomparob111.github.io/budget-studio/ — hard refresh after deploy

---

## Recommended next (pick one)

1. **TestFlight** — sister and others on real devices.
2. **LLC registration** — then update terms/privacy operator language to **MCL LABS LLC**.
3. **Before public publish (auth)** — CAPTCHA + rate limits; enable Apple/Google/passkeys per [`docs/AUTH_PROVIDERS.md`](AUTH_PROVIDERS.md).
4. **Launch smoke test** — [`LAUNCH_CHECKLIST.md`](../LAUNCH_CHECKLIST.md) §3.
5. **Widget** — still shows safe-to-spend; consider aligning with **Check left**.

**Do not start:** bank sync / Plaid.

---

## For next agent

- Start from this file + [`AGENTS.md`](../AGENTS.md); **do not explore the whole repo**.
- Push GitHub Pages **only when the user asks**.
- **Do not change budget math** unless explicitly asked.
- Product is **ready for daily use**; public launch needs auth hardening + TestFlight.
