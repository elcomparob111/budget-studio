# Handoff — Budget Studio

**Pinned:** July 25, 2026  
**Branch / tip:** `main`  
**Owner preference:** product is **good for day-to-day use**. Next agent picks from **Recommended next** below.

Read [`AGENTS.md`](../AGENTS.md) first, then this file. Do not re-litigate shipped P0 work unless fixing a bug.

---

## Just shipped (Jul 25)

| Area | Status | Notes |
|------|--------|--------|
| Web Check-left Home parity | Done | Web Home matches iOS: Check left hero + wash, check ring (period spent/income), In/Out, month stepper in hero, Month plan bar, Needs/Wants/Savings groups, tap-to-expand expenses. SW **v69**. |
| Web Activity / Savings / Settings polish | Done | Activity type+category chips + day-grouped list (charts kept). Savings “Saved so far” hero. Settings section labels + account hero. |
| iOS Check-left redesign (prior) | Done | `410f1f8d` — Home/Activity/Savings/Settings polish; August pay-period fix; auth-provider docs. |

### Paths to know

- Web: `app.js`, `styles.css`, `index.html`, `sw.js` (cache `budget-studio-v69`)
- iOS: `ios/BudgetStudio/Views/OverviewView.swift` (source of truth for Home composition)
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
