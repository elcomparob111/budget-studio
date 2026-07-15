# Handoff — Budget Studio

**Pinned:** July 14, 2026  
**Branch / tip:** `main` (see latest commit after this file lands)  
**Owner preference:** stop feature crunch; next agent should pick up from **Recommended next** below.

Read [`AGENTS.md`](../AGENTS.md) first, then this file. Do not re-litigate shipped P0 work unless fixing a bug.

---

## Just shipped (this session arc)

| Area | Status | Notes |
|------|--------|--------|
| Shared budgets (web) | Done | Invite/join/realtime/leave Option A; authorship tags on Activity |
| Shared budgets (iOS) | Done | Settings share, Contacts/Messages invite, paste join, realtime, leave Option A, author chips |
| Bill reminders (iOS) | Done | **Local** notifications (not APNs). Settings → Recurring → Bill reminders. 9am on due day, expenses only |
| Transaction delete (iOS) | Done | Delete lives in **edit sheet** only (no always-on trash on list) |
| Home Screen widget | Done (polish loved) | Safe-to-spend + tap → `budgetstudio://add`. App Group `group.com.budgetstudio.app` |
| Web IA (Home / Activity / Goals / Settings) | Done (web + iOS) | Activity income-vs-spent + category breakdown; Budgets in Settings; Savings goals tab (`savingsGoals` synced). |
| Docs | Updated | `SHARED_BUDGETS.md`, `ROADMAP.md` reflect shipped shared budgets |
| Web touch targets | Done | SW **v59**; undo-on-delete already worked |
| Sync refresh (web + iOS) | Done | Re-fetch cloud on focus/visibility/online when cloud `updatedAt` > local; iOS `sanitizeState` preserves `savingsGoals` |
| Biweekly pay periods (web + iOS) | Done | Periods show payday → next payday (e.g. Jul 8–22); preview list on Home + Pay schedule; SW **v61**; incomes must be logged manually |

### Widget / iOS paths to know

- Widget: `ios/BudgetStudioWidget/`
- Shared snapshot: `ios/Shared/WidgetSnapshot.swift`
- Publish from app: `BudgetStore.publishWidgetSnapshot()`
- Deep link: `budgetstudio://add` → `pendingQuickAdd` → `MainTabView`
- Project: `ios/project.yml` (run `xcodegen generate` after target edits)
- Entitlements: App Group on app + widget; first device build may need Xcode to confirm the group

---

## Recommended next (pick one)

1. **TestFlight** — highest leverage: family on real devices (shared budgets, reminders, widget, Savings). See `ios/README.md` / `docs/DEPLOYMENT.md`.
2. **Launch smoke test** — still open in [`LAUNCH_CHECKLIST.md`](../LAUNCH_CHECKLIST.md) §3 (confirm email, sync, isolation, delete cloud data). Operator/dashboard, not a big code task.
3. **Quick-entry leftovers (P1)** — Watch app and/or Siri shortcut; widget is done.
4. **Launch hygiene** — AI logo provenance (`legal/AI_ASSETS.md`), trademark (`legal/TRADEMARK.md`), self-serve account deletion (Edge Function, service_role server-side only).
5. **Before public publish (auth)** — Confirm Supabase Auth rate limits; enable CAPTCHA / leaked-password protection. See [`LAUNCH_CHECKLIST.md`](../LAUNCH_CHECKLIST.md) §2 and [`legal/RELEASE_CHECKLIST.md`](../legal/RELEASE_CHECKLIST.md). Not urgent for family/TestFlight.

**Do not start:** bank sync / Plaid (compliance jump). Remote APNs for reminders can wait; local notifications cover the P1 “reminders” half.

---

## Explicitly not done / stale doc lines

- `docs/ROADMAP.md` Product still says “Push notifications for bill reminders” — treat as **remote push**; local iOS reminders are shipped.
- Confirm-email Site URL must stay `https://elcomparob111.github.io/budget-studio/` (with path).
- Leave behavior is **Option A** (keep shared snapshot minus partner’s tagged txs), not the old “personal untouched / no copy-back” note (fixed in SHARED_BUDGETS).

---

## Verify tips

- Widget: install app once signed-in, then add **Safe to spend** widget; remove/re-add after UI changes.
- Shared: two accounts, invite via Messages/Contacts, edit both sides, leave keeps own entries.
- Reminders: toggle on, allow notifications, recurring expense due tomorrow → 9:00 local.

---

## Out of scope for agents unless asked

- Committing `.claude/`
- Force-push / amending pushed commits
- Changing budget math without an explicit ask
