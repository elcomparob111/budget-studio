# Shared/couples budgets — design (P0)

Status: **designed, not applied**. Schema in [`supabase/shared-budgets.sql`](../supabase/shared-budgets.sql)
is ready for review; nothing has been run against the live Supabase project and
no client code ships until the schema is applied and smoke-tested.

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
- `is_budget_member()` is a definer helper to avoid recursive RLS between
  `shared_budgets` and `budget_members`.
- Invite tokens: UUID, 7-day expiry, single-use (`used_by`), revocable by
  creator (delete).

## Client work (after schema applies)

1. `sync.js`: `createSharedBudget()`, `acceptInvite(token)`,
   `fetchSharedBudget(id)` / `pushSharedBudget(id, payload)`, and a
   `subscribeSharedBudget(id, onChange)` realtime channel.
2. `app.js`: active-budget pointer in localStorage
   (`{ kind: "personal" | "shared", id }`), a Settings “Share this budget”
   card (create + copy link, member list, leave), `?join=` handling on load
   (after auth), and a subtle “synced with <partner>” indicator.
3. iOS: same RPCs through supabase-swift; realtime channel on the row.

## Open questions for Rob

- Seed the shared budget from the inviter's current state (assumed yes)?
- Should leaving copy the latest shared state back into the leaver's personal
  budget, or leave their old personal state as-is?
- One shared budget per user for v1 (assumed yes — simplifies the switcher)?

## Rollout

1. Review this doc + SQL. 2. Run SQL in Supabase SQL editor (staging first if
available). 3. Verify with the queries at the bottom of the SQL file. 4. Build
client layer behind a “Share budget” entry point. 5. Two-account smoke test
(invite, join, both-sides edit, realtime, leave). 6. Ship.
