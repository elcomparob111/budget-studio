# Handoff — Budget Studio

**Pinned:** July 15, 2026  
**Branch / tip:** `main` @ `a160c7e` (pushed)  
**Owner preference:** stop feature crunch; next agent picks from **Recommended next** below.

Read [`AGENTS.md`](../AGENTS.md) first, then this file. Do not re-litigate shipped P0 work unless fixing a bug.

---

## Just shipped (this session / recent commits)

| Area | Status | Notes |
|------|--------|--------|
| Sync refresh (web + iOS) | Done | Web re-fetches on focus/visibility/online when cloud `updatedAt` > local (`0b73f97`). iOS foreground refresh; `sanitizeState` preserves `savingsGoals`. |
| Biweekly pay periods | Done | Periods show payday → next payday (e.g. Jul 8–22); preview on Home + Pay schedule (`0b73f97`). |
| Supabase security advisors | Done | `is_budget_member` → `private` schema (`4a91780`); `create_shared_budget` + `accept_budget_invite` → SECURITY INVOKER + private triggers (`1d498e9`). **Only remaining advisor:** `auth_leaked_password_protection` (WARN) — **requires the Pro plan**, so it cannot be cleared on the current plan. Not a blocker for family/TestFlight. Verified via `get_advisors` Jul 15. |
| Shared budgets — RLS regression + retest | Done | `1d498e9` broke **creation**: `create_shared_budget` is SECURITY INVOKER, so `returning id into bid` applied the SELECT policy (`private.is_budget_member(id)`) to the new row, but owner membership comes from an AFTER INSERT trigger (queued to end of statement) → `new row violates row-level security policy`. Fixed in `18f5395` by generating the id up front (no read-back). Applied live **and** in `supabase/shared-budgets.sql`. Invite → accept retested by owner Jul 15: **works**. |
| Pay UI (web ↔ iOS parity) | Done | **Option B:** Home metrics-only with optional “Next” line; full schedule in Pay schedule settings (`33a0ec8`, `58b9f4d`, `2775c84`). |
| Recurring web UI | Done | Matched iOS settings sheet: modal, chips, bill reminders, trash rows (`c96fc28`). SW **v65**. |
| Xcode 26 settings + warnings | Done | `692b97c` settings/`.eq` filter, `a28bbb8` BudgetStore bindings. `xcodebuild` → BUILD SUCCEEDED, **0 warnings**. `UIRequiresFullScreen` deliberately left `false` (iPad Split View). |
| Shared budgets (web + iOS) | Done (prior arc) | Invite/join/realtime/leave Option A; authorship tags on Activity |
| Bill reminders (iOS) | Done (prior arc) | **Local** notifications. Settings → Recurring → Bill reminders. 9am on due day, expenses only |
| Home Screen widget | Done (prior arc) | Safe-to-spend + tap → `budgetstudio://add`. App Group `group.com.budgetstudio.app` |
| Web IA (Home / Activity / Goals / Settings) | Done | Activity income-vs-spent + category breakdown; Budgets in Settings; Savings goals tab (`savingsGoals` synced) |
| Home ring card layout (iOS) | Done | Ring was 3rd item in 2-col `LazyVGrid` → row-2 left cell with empty right, labels wrapping. Lifted to full-width row: ring left, “Budget used / On track” beside, “Cash left $X” trailing; over-plan tints red. Verified on simulator (`a160c7e`). |
| Activity ordering (iOS ↔ web) | Done | Transactions above analysis charts (`deaf14d`, `1bbb12b`). |

### Key commits (newest first)

`a160c7e` ring card full-width · `deaf14d` Activity order · `c96fc28` recurring web · `2775c84` pay Option B · `58b9f4d` Home schedule trim · `33a0ec8` pay preview · `1d498e9` / `4a91780` RPC hardening · `0b73f97` sync + biweekly

### Paths to know

- Web: `app.js`, `sync.js`, `sw.js` (cache `budget-studio-v65`)
- Widget: `ios/BudgetStudioWidget/`, `ios/Shared/WidgetSnapshot.swift`
- iOS project: `ios/project.yml` (run `xcodegen generate` after target edits)
- Shared-budget RPCs: `supabase/` migrations / `rls.sql`

---

## Uncommitted local (verify before assuming shipped)

| Path | What |
|------|------|
| `LAUNCH_CHECKLIST.md`, `legal/RELEASE_CHECKLIST.md` | Auth rate limits / CAPTCHA / leaked-password wording (“before public publish”) |
| `skills-lock.json` | Agent skills lockfile |
| `.agents/skills/supabase/`, `.agents/skills/supabase-postgres-best-practices/`, `.agents/skills/hallmark/` | Agent skills (plus duplicate `* 2.md` copies — ignore) |
| `ios/build-*/`, `ios/BudgetStudio 2.xcodeproj/` | Untracked local build dirs / duplicate xcodeproj — ignore / do not commit |

The iOS items above (`project.yml`, `Info.plist`, `SupabaseService.swift`) were committed in `692b97c`; `Info.plist` ended up unchanged once the fullscreen flag was reverted.

---

## Recommended next (pick one)

1. ~~Commit Xcode warning fixes~~ — **done** (`692b97c`, `a28bbb8`). Build is warning-free.
2. ~~Smoke-test shared budgets~~ — **done** Jul 15. Create was broken by the RPC hardening and is fixed (`18f5395`); invite → accept retested and working. **Still unexercised:** realtime partner sync and leave Option A after the SECURITY INVOKER switch — worth a pass during TestFlight.
3. **TestFlight** — family on real devices (shared budgets, reminders, widget, Savings). See `ios/README.md` / `docs/DEPLOYMENT.md`.
4. **Launch smoke test** — [`LAUNCH_CHECKLIST.md`](../LAUNCH_CHECKLIST.md) §3 (confirm email, sync, isolation, delete cloud data).
5. **Before public publish (auth)** — rate limits + CAPTCHA are configurable now; leaked-password protection is **Pro-only** and cannot be enabled on the current plan. Fine to defer for family/TestFlight.
6. **Visual polish** — Hallmark skill installed (`.agents/skills/hallmark`); use for landing/legal polish or `hallmark audit` before public publish — do not casually redesign the live PWA. User may still want feedback on Home paycheck line after hard refresh on live site.
7. **iPad Home metrics grid (optional)** — on regular width the metric grid is **4 columns**; Income + Spent leave two empty cells (same structural class of bug as the pre-`a160c7e` ring card). Only if user asks.
8. **Pay period vs month duplication (optional, ask first)** — Pay period card may echo Home metric numbers (Income/Spent/Cash left vs Check left); may be intentional when month ≈ pay period. Review with user before changing.

**Do not start:** bank sync / Plaid. Remote APNs can wait; local iOS reminders cover P1.

---

## Explicitly not done / stale doc lines

- **iPad 4-col Home metrics** — empty grid cells on regular width (see Recommended next #7).
- **Pay period card duplication** — may be intentional; confirm with user before changing (see #8).
- `docs/ROADMAP.md` Product still says “Push notifications for bill reminders” — treat as **remote push**; local iOS reminders are shipped.
- Confirm-email Site URL must stay `https://elcomparob111.github.io/budget-studio/` (with path).
- Leave behavior is **Option A** (keep shared snapshot minus partner’s tagged txs). See `docs/SHARED_BUDGETS.md`.

---

## Verify tips

- **Live web:** https://elcomparob111.github.io/budget-studio/ — **hard refresh** after deploy (SW v65).
- Shared: two accounts, invite, edit both sides, leave keeps own entries.
- **Supabase MCP is configured** (`.mcp.json`, project `dhlaqqghjfmgdlkfxlxg`). Authenticate with `claude /mcp` **from this repo** — running it elsewhere authenticates that directory's project instead. Restart the session afterwards; MCP tools bind at startup. `get_logs`/`execute_sql` beat guessing for any RLS or RPC bug.
- **`supabase/*.sql` is applied by hand** — there is no CLI, no link, no migrations dir. The repo is *not* proof of what prod runs; query the database (`pg_proc.prosecdef`, `pg_policies`) before trusting a file.
- **RLS trap (bit us once):** in a SECURITY INVOKER function, `insert ... returning` applies the **SELECT** policy to the new row. If that policy depends on a row created by an AFTER INSERT trigger, it fails — after-row triggers are queued to end of statement. Don't read back; generate the id up front. See `18f5395`.
- **Testing a change means testing the current code.** The Jul 14 shared-budget test predated the Jul 15 RPC rewrite and gave false confidence; the create path was broken the whole time.
- Pay: Home shows metrics + optional Next; full schedule under Settings → Pay schedule.
- Recurring web: modal matches iOS (chips, bill reminders toggle, trash on rows).
- Widget: install signed-in, add **Safe to spend** widget; re-add after UI changes.

---

## For next agent

- Start from this file + [`AGENTS.md`](../AGENTS.md); **do not explore the whole repo**.
- Push GitHub Pages **only when the user asks** (recent sessions often requested web UX pushes).
- **Do not change budget math** unless explicitly asked.
- Do not commit `.claude/`, `ios/build-*/`, or force-push / amend pushed commits.

---

## Out of scope unless asked

- Committing `.claude/` or local build artifacts
- Force-push / amending pushed commits
- Changing budget math without an explicit ask
