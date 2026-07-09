# API — Budget Studio

**Last updated:** July 9, 2026  

There is **no custom Node/REST API**. The application API is **Supabase Auth + PostgREST** against Postgres, constrained by RLS.

Base URL (project): `https://dhlaqqghjfmgdlkfxlxg.supabase.co`  
Client auth: anon / publishable key only (see `sync-config.js` / iOS `SyncConfig`).

---

## Auth (Supabase Auth)

Used by web (`sync.js`) and iOS (`SupabaseService`).

| Operation | Client method | Notes |
|-----------|---------------|-------|
| Sign up | `auth.signUp({ email, password, options.data.name })` | Client validates email/password strength first |
| Sign in | `auth.signInWithPassword` | |
| Sign out | `auth.signOut` | Clears session; UI clears local caches |
| Password reset email | `auth.resetPasswordForEmail` | Redirect → live GitHub Pages URL |
| Update password | `auth.updateUser({ password })` | After recovery link |
| Session | `auth.getSession` / `onAuthStateChange` | JWT in client storage |

Password hashing and session issuance are server-side (Supabase).

---

## Data: `public.budgets`

Schema (from [`../supabase/rls.sql`](../supabase/rls.sql)):

| Column | Type | Notes |
|--------|------|-------|
| `user_id` | uuid PK | FK → `auth.users(id)` ON DELETE CASCADE |
| `state` | jsonb | Full budget document (categories, transactions, …) |
| `updated_at` | bigint | Client-supplied sync watermark |
| `name` | text | Display / account label (capped in client) |

### RLS

- Enabled on `budgets`.
- `anon`: no table grants.
- `authenticated`: SELECT / INSERT / UPDATE / DELETE where `auth.uid() = user_id`.

### Client operations

| Op | PostgREST shape | App wrapper |
|----|-----------------|-------------|
| Read | `from('budgets').select('state, updated_at, name').eq('user_id', sessionUid).maybeSingle()` | `fetchCloudBudget` |
| Upsert | `from('budgets').upsert({ user_id, state, updated_at, name })` | `pushCloudBudget` |
| Delete row | `from('budgets').delete().eq('user_id', sessionUid)` | `deleteOwnBudgetAndSignOut` |

Defense-in-depth: wrappers call `assertOwnUserId(sessionUid, requestedUid)` and sanitize `state` before apply/upsert.

---

## `state` JSON (application contract)

Sanitized by `sanitizeBudgetState` / `sanitizeCloudPayload` in `security.js`. High-level:

- Whitelisted keys only; `__proto__` / `constructor` stripped
- Categories / transactions arrays capped (`BUDGET_LIMITS`)
- Names/descriptions strip `<>` and length-capped
- Transaction types limited to `Income` | `Expense`

Treat cloud JSON as **untrusted** even when RLS-scoped (defense against buggy clients and future bugs).

---

## Not exposed

| Item | Status |
|------|--------|
| RPC / Edge Functions | None in repo today |
| Admin delete Auth user | Dashboard or future privileged Edge Function |
| service_role | Forbidden in clients |
| Realtime subscriptions | Not used |

---

## Versioning

Schema changes: update `supabase/rls.sql`, `supabase-schema.sql`, this file, and both clients. Prefer additive jsonb fields with sanitizer allowlists updated together.

---

## Related

- [`ARCHITECTURE.md`](ARCHITECTURE.md)
- [`SECURITY.md`](SECURITY.md)
- [`DEPLOYMENT.md`](DEPLOYMENT.md)
