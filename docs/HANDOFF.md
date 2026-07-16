# Handoff — Budget Studio

**Pinned:** July 15, 2026 (evening)  
**Branch / tip:** `main` @ `5109edb` (pushed)  
**Owner preference:** stop feature crunch; product is **good for day-to-day use**. Next agent picks from **Recommended next** below.

Read [`AGENTS.md`](../AGENTS.md) first, then this file. Do not re-litigate shipped P0 work unless fixing a bug.

---

## Just shipped (Jul 15 evening + recent commits)

| Area | Status | Notes |
|------|--------|--------|
| Home ring card layout (iOS) | Done | Ring was 3rd item in 2-col `LazyVGrid` → row-2 left cell with empty right. Lifted to full-width row (`a160c7e`). |
| iPad Home Income/Spent row | Done | Equal-width cards fill the row on regular width — no dead grid cells (`c324996`). |
| Widget App Group storage | Done | CFPrefs suite noise → JSON file in group container (`87fef12`, `1bec195`). Snapshot at `WidgetSnapshot.swift` path in group container. |
| iOS dark mode | Done | System / Light / Dark in Settings (`91ce6a4`). **Local only** — does not sync to cloud. |
| Settings toggles (Face ID, bill reminders, setup) | Done | Green tint; Face ID no longer stuck off / invisible in dark mode (`b3f3c80`, `9fc0b2c`). Face ID + bill reminders **local only**. |
| iOS budget editor auto-save | Done | Saves on blur/dismiss like web — swipe-down no longer loses amounts (`79f55db`). |
| Hallmark skill | Done | Installed for publish-time polish (`6df22aa`). Noted in `LAUNCH_CHECKLIST.md`, `legal/RELEASE_CHECKLIST.md`. **Do not casually redesign the live PWA.** |
| Legal contact email | Done | `mcl.labss@gmail.com` across policies (`5109edb`). **Wait** to rename operator to **MCL LABS LLC** until entity is registered. |
| Sync refresh (web + iOS) | Done | Web re-fetches on focus/visibility/online when cloud `updatedAt` > local (`0b73f97`). iOS foreground refresh; `sanitizeState` preserves `savingsGoals`. |
| Web ↔ iOS sync audit | Done | **Cloud:** budget state fields (`budgets.data` JSON). **Local-only:** theme, Face ID, bill reminders, widget snapshot. |
| Biweekly pay periods | Done | Periods show payday → next payday; preview on Home + Pay schedule (`0b73f97`). |
| Supabase security / RPC hardening | Done | `is_budget_member` → `private` schema (`4a91780`); `create_shared_budget` + `accept_budget_invite` → SECURITY INVOKER + private triggers (`1d498e9`). Create-path RLS regression fixed (`18f5395`). Invite → accept **retested Jul 15 — works**. |
| Shared budgets (web + iOS) | Done | Invite/join/realtime/leave Option A; authorship tags on Activity. Sister onboarded on **own account** (not shared budget); Xcode sideload install worked. |
| Pay UI (web ↔ iOS parity) | Done | **Option B:** Home metrics-only + optional “Next” line; full schedule in Pay schedule settings. |
| Recurring web UI | Done | Modal matches iOS: chips, bill reminders, trash rows (`c96fc28`). SW **v65**. |
| Activity ordering (iOS ↔ web) | Done | Transactions above analysis charts (`deaf14d`, `1bbb12b`). |
| Xcode 26 settings + warnings | Done | `692b97c`, `a28bbb8`. `xcodebuild` → BUILD SUCCEEDED, **0 warnings**. |
| Bill reminders (iOS) | Done | **Local** notifications. Settings → Recurring → Bill reminders. 9am on due day, expenses only. |
| Home Screen widget | Done | Safe-to-spend + tap → `budgetstudio://add`. App Group `group.com.budgetstudio.app`. |
| Web IA (Home / Activity / Goals / Settings) | Done | Activity income-vs-spent + category breakdown; Budgets in Settings; Savings goals tab (`savingsGoals` synced). |

**Supabase advisor:** only `auth_leaked_password_protection` (WARN) remains — **Pro plan required**; not a blocker for family/TestFlight.

### Key commits (newest first)

`5109edb` legal email · `6df22aa` Hallmark skill · `79f55db` iOS editor auto-save · `9fc0b2c`/`b3f3c80` toggle fixes · `91ce6a4` dark mode · `c324996` iPad Income/Spent · `87fef12`/`1bec195` widget JSON · `a160c7e` ring full-width · `18f5395` shared-budget create fix · `0b73f97` sync + biweekly

### Paths to know

- Web: `app.js`, `sync.js`, `sw.js` (cache `budget-studio-v65`)
- Widget: `ios/BudgetStudioWidget/`, `ios/Shared/WidgetSnapshot.swift`
- iOS project: `ios/project.yml` (run `xcodegen generate` after target edits)
- Shared-budget RPCs: `supabase/` migrations / `rls.sql`
- Legal: `legal/` — contact email updated; entity rename deferred

---

## Uncommitted local (verify before assuming shipped)

| Path | What |
|------|------|
| `.agents/skills/supabase/`, `.agents/skills/supabase-postgres-best-practices/` | Agent skills (duplicate `* 2.md` copies — ignore) |
| `skills-lock.json` | Agent skills lockfile |
| `.claude/` | Local Claude config — do not commit |
| `ios/build-*/`, `ios/BudgetStudio 2.xcodeproj/` | Untracked local build dirs / duplicate xcodeproj — ignore |

`LAUNCH_CHECKLIST.md` and `legal/RELEASE_CHECKLIST.md` Hallmark + auth-hardening notes are committed in `6df22aa` / `7f68966`.

---

## Recommended next (pick one)

1. **TestFlight** — sister and others on real devices (better than Xcode sideload). Shared budgets, reminders, widget, Savings. See `ios/README.md` / `docs/DEPLOYMENT.md`. **Still unexercised after RPC hardening:** realtime partner sync and leave Option A — worth a pass during TestFlight.
2. **LLC registration** — then update terms/privacy operator language to **MCL LABS LLC** (contact email already `mcl.labss@gmail.com`).
3. **Before public publish (auth)** — rate limits + CAPTCHA configurable; leaked-password protection is **Pro-only** on current plan. Fine to defer for family/TestFlight.
4. **Launch smoke test** — [`LAUNCH_CHECKLIST.md`](../LAUNCH_CHECKLIST.md) §3 (confirm email, sync, isolation, delete cloud data).
5. **Visual polish (optional, at publish)** — Hallmark skill (`.agents/skills/hallmark`) for landing/legal polish or `hallmark audit` — not for casual PWA redesign.
6. **Pay period vs month duplication (optional, ask first)** — Pay period card may echo Home metric numbers; may be intentional when month ≈ pay period. Review with user before changing.

**Do not start:** bank sync / Plaid. Remote APNs can wait; local iOS reminders cover P1.

---

## Explicitly not done / stale doc lines

- **Entity rename in legal docs** — wait for LLC registration before “MCL LABS LLC” operator language.
- **Pay period card duplication** — may be intentional; confirm with user before changing (see Recommended next #6).
- `docs/ROADMAP.md` Product still says “Push notifications for bill reminders” — treat as **remote push**; local iOS reminders are shipped.
- Confirm-email Site URL must stay `https://elcomparob111.github.io/budget-studio/` (with path).
- Leave behavior is **Option A** (keep shared snapshot minus partner’s tagged txs). See `docs/SHARED_BUDGETS.md`.

---

## Verify tips

- **Live web:** https://elcomparob111.github.io/budget-studio/ — **hard refresh** after deploy (SW v65).
- **Sync:** cloud = budget JSON state; theme / Face ID / bill reminders stay per-device.
- Shared: two accounts, invite, edit both sides, leave keeps own entries.
- **Supabase MCP is configured** (`.mcp.json`, project `dhlaqqghjfmgdlkfxlxg`). Authenticate with `claude /mcp` **from this repo** — running it elsewhere authenticates that directory's project instead. Restart the session afterwards; MCP tools bind at startup.
- **`supabase/*.sql` is applied by hand** — there is no CLI, no link, no migrations dir. The repo is *not* proof of what prod runs; query the database (`pg_proc.prosecdef`, `pg_policies`) before trusting a file.
- **RLS trap (bit us once):** in a SECURITY INVOKER function, `insert ... returning` applies the **SELECT** policy to the new row. If that policy depends on a row created by an AFTER INSERT trigger, it fails — after-row triggers are queued to end of statement. Don't read back; generate the id up front. See `18f5395`.
- **Testing a change means testing the current code.** The Jul 14 shared-budget test predated the Jul 15 RPC rewrite and gave false confidence; the create path was broken the whole time.
- iOS editor: edit amount → swipe sheet down → amount should persist (`79f55db`).
- Widget: install signed-in, add **Safe to spend** widget; re-add after UI changes.

---

## For next agent

- Start from this file + [`AGENTS.md`](../AGENTS.md); **do not explore the whole repo**.
- Push GitHub Pages **only when the user asks**.
- **Do not change budget math** unless explicitly asked.
- Do not commit `.claude/`, `ios/build-*/`, or force-push / amend pushed commits.
- Product is **ready for daily use**; public launch needs auth hardening + TestFlight (or App Store) for distribution beyond Xcode sideload.

---

## Out of scope unless asked

- Committing `.claude/` or local build artifacts
- Force-push / amending pushed commits
- Changing budget math without an explicit ask
- Casual PWA redesign (Hallmark is for deliberate publish polish only)
- Renaming legal entity before LLC is registered
