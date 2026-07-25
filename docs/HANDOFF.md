# Handoff — Budget Studio

**Pinned:** July 25, 2026  
**Branch / tip:** `main`  
**Owner preference:** product is **good for day-to-day use**. Next agent picks from **Recommended next** below.

Read [`AGENTS.md`](../AGENTS.md) first, then this file. Do not re-litigate shipped P0 work unless fixing a bug.

---

## Just shipped (Jul 25)

| Area | Status | Notes |
|------|--------|--------|
| Activity spend calendar (web + iOS) | Done | Month grid under Activity hero: per-day spent + income, select day → strip + filter list. Tap again / Clear to reset. SW **v71**. |
| Home richness (web + iOS) | Done | Payday countdown, over-plan watch, Recent, Goals peek. SW v70. |
| Web Check-left Home parity | Done | Check left hero matching iOS. |

### Paths to know

- Web Activity calendar: `app.js` (`renderActivityCalendar`), `index.html`, `styles.css`
- iOS Activity calendar: `ios/BudgetStudio/Views/TransactionsView.swift`
- Live: https://elcomparob111.github.io/budget-studio/ — hard refresh after deploy

---

## Recommended next (pick one)

1. **TestFlight** — sister and others on real devices.
2. **LLC registration** — then update terms/privacy operator language to **MCL LABS LLC**.
3. **Before public publish (auth)** — CAPTCHA + rate limits; Apple/Google/passkeys per [`docs/AUTH_PROVIDERS.md`](AUTH_PROVIDERS.md).
4. **Launch smoke test** — [`LAUNCH_CHECKLIST.md`](../LAUNCH_CHECKLIST.md) §3.
5. **Widget** — consider aligning with **Check left**.

**Do not start:** bank sync / Plaid.

---

## For next agent

- Start from this file + [`AGENTS.md`](../AGENTS.md); **do not explore the whole repo**.
- Push GitHub Pages **only when the user asks**.
- **Do not change budget math** unless explicitly asked.
