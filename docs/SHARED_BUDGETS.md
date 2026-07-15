# Shared/couples budgets — design (P0)

Status: **shipped (web + iOS, 2026-07-14)**. Schema applied; anon-role
lockout verified live (all tables/RPCs return 42501 for anon). Invite, join,
realtime, leave (Option A), and authorship tags are live on web and iOS.
Owner-validated smoke across web + iOS; operators may re-run the two-account
checklist below after schema or RPC changes.

## Why this shape

The app stores one JSON `state` blob per user (`public.budgets`, last-write-wins
on `updated_at`). Rewriting to normalized rows would be a multi-week detour, so
sharing is **additive**: a `shared_budgets` table with the identical
blob + `updated_at` model, plus `budget_members` and single-use, expiring
`budget_invites`. Personal budgets and existing users are untouched; a couple's
budget is simply a second row both clients point at.

- **Invite loop** (the growth wedge): owner taps “Share budget” → app seeds a
  shared budget from their current state via the `create_shared_budget` RPC,
  inserts an invite, and builds a link `https://<app>/?join=<token>`.
- **Join**: partner opens the link signed in → client calls
  `accept_budget_invite(token)` → membership row → client switches its cloud
  read/write target to the shared row.
- **Live sync**: Supabase Realtime (`postgres_changes` on `shared_budgets`)
  pushes the partner's writes; client applies them with the existing
  newer-`updated_at`-wins merge already used for cloud fetch.

## Security notes

- All three tables are RLS-on, anon fully revoked.
- Membership/invite writes go through `security definer` RPCs so tokens are
  never enumerable via SELECT and membership can't be self-granted.
- `private.is_budget_member()` is a definer helper (non-exposed schema) to avoid
  recursive RLS between `shared_budgets` and `budget_members`.
- Invite tokens: UUID, 7-day expiry, single-use (`used_by`), revocable by
  creator (delete).

## Client work (after schema applies)

1. [x] `sync.js`: `createSharedBudget()`, `acceptInvite(token)`,
   `fetchSharedBudget(id)` / `pushSharedBudget(id, payload)`, and a
   `subscribeSharedBudget(id, onChange)` realtime channel.
2. [x] `app.js`: active-budget pointer in localStorage
   (`{ kind: "personal" | "shared", id }`), a Settings “Share this budget”
   card (create + copy link, member list, leave), `?join=` handling on load
   (after auth), authorship tags, and a subtle “synced with <partner>”
   indicator.
3. [x] iOS: same RPCs through supabase-swift; invite (incl. Contacts/Messages),
   join via paste / URL scheme, realtime channel, leave Option A, Activity
   author tags.

## Decisions (Rob, 2026-07-13; leave updated 2026-07-14)

- **Seed from inviter's state**: yes — partner joins into a copy of the
  inviter's current budget.
- **On leave (Option A)**: leaver keeps a personal copy of the shared
  snapshot with the partner's tagged transactions removed. Not the earlier
  “old personal untouched / no copy-back” plan.
- **V1 scope**: one shared budget per user — no switcher UI; you're solo or
  in one shared budget.

## Rollout

1. Review this doc + SQL. 2. Run SQL in Supabase SQL editor (staging first if
available). 3. Verify with the queries at the bottom of the SQL file. 4. Build
client layer behind a “Share budget” entry point. 5. Two-account smoke test
(invite, join, both-sides edit, realtime, leave) — web + iOS validated by
owner. 6. Ship.
