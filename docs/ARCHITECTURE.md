# Architecture — Budget Studio

**Last updated:** July 9, 2026  
**Verified model:** Static PWA on GitHub Pages + Supabase Auth/DB + native iOS. **No custom Node API.**

---

## System context

```text
┌─────────────────┐     HTTPS      ┌──────────────────────────┐
│  Web PWA        │───────────────▶│  GitHub Pages            │
│  (static JS)    │◀───────────────│  (HTML/CSS/JS/SW only)   │
└────────┬────────┘                └──────────────────────────┘
         │
         │  supabase-js (CDN) + anon key
         ▼
┌─────────────────┐                ┌──────────────────────────┐
│  iOS SwiftUI    │───────────────▶│  Supabase                │
│  supabase-swift │                │  Auth + Postgres + RLS   │
└─────────────────┘                └──────────────────────────┘
```

| Layer | Technology | Role |
|-------|------------|------|
| Web UI | Vanilla JS (`app.js`), CSS, `index.html` | Budget UX, local cache, PWA |
| Web sync | `sync.js` + `sync-config.js` | Auth + CRUD via PostgREST |
| Web hardening | `security.js` | XSS escape, validation, sanitization, UX lockout |
| Offline | `sw.js` | Same-origin static asset cache only |
| Backend | Supabase Auth + `public.budgets` | Identity + one JSON row per user |
| AuthZ | Postgres RLS | `auth.uid() = user_id` |
| iOS | SwiftUI + SPM Supabase | Native client, same schema |

---

## Data model

Single application table (plus Auth schema owned by Supabase):

| Table | Key | Payload |
|-------|-----|---------|
| `public.budgets` | `user_id` (PK → `auth.users`) | `state` jsonb, `updated_at` bigint, `name` text |

Full budget domain (categories, transactions, settings) lives inside `state`. See [`API.md`](API.md) and [`../supabase/rls.sql`](../supabase/rls.sql).

---

## Trust boundaries

1. **Browser / iOS device** — untrusted; XSS can steal JWTs stored by supabase-js (local storage / memory). Mitigate with CSP + `escapeHtml` + payload sanitization.
2. **Anon key** — public by design; **not** a secret. Authorization is RLS.
3. **Service role** — never in clients or this repo’s frontend. Operator-only / future Edge Functions.
4. **GitHub Pages** — serves static files only; no server-side session or secrets.

---

## Sync flow (web)

1. `initSync` creates Supabase client with anon key.
2. Auth state drives UI; local state keyed by uid.
3. `fetchCloudBudget` / `pushCloudBudget` assert session uid matches requested uid, then select/upsert under RLS.
4. Import/export stay client-side; import ignores embedded `user_id`.

iOS mirrors ownership checks in `SupabaseService` / `BudgetStore`.

---

## What this architecture is good for

- Family / early commercial personal budgeting
- Fast iteration without operating a custom API
- Clear RLS story for per-user isolation

## What it is not (yet)

- Multi-tenant org / shared household accounts
- Bank aggregation or PCI scope
- Millions of users without Supabase plan upgrades, monitoring, CDN hardening, and likely a BFF or Edge layer for admin/deletion/rate policy
- Custom HttpOnly cookie session architecture (Supabase JS client defaults)

See [`ROADMAP.md`](ROADMAP.md) and [`PRODUCTION_AUDIT.md`](PRODUCTION_AUDIT.md).
