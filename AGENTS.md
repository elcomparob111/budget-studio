# AGENTS.md — Budget Studio

Short onboarding for AI coding agents. **Do not read the whole codebase first.** Start from the docs below; open source files only when implementing a change.

## What this is

**Budget Studio** is a personal budgeting app: a static web PWA plus a native iOS client, both syncing through Supabase (Auth + Postgres + RLS). No custom Node API.

## Stack

| Layer | Location / tech |
|-------|-----------------|
| Web (GitHub Pages) | Vanilla JS/CSS/HTML PWA at repo root |
| Backend | Supabase Auth + `public.budgets` (JSON state per user) |
| iOS | SwiftUI under `ios/` (same Supabase accounts/schema) |

Live site: https://elcomparob111.github.io/budget-studio/

## Read first (in order)

1. [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — system design, trust boundaries, sync
2. [`docs/PRODUCTION_AUDIT.md`](docs/PRODUCTION_AUDIT.md) — production readiness
3. [`README.md`](README.md) — run locally, features, doc index

Then as needed:

- [`docs/SECURITY.md`](docs/SECURITY.md)
- [`docs/API.md`](docs/API.md)
- [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md)
- [`LAUNCH_CHECKLIST.md`](LAUNCH_CHECKLIST.md)
- [`legal/`](legal/)

## Key paths

| Path | Role |
|------|------|
| `app.js` | Web budget UX and local state |
| `sync.js` | Auth + cloud CRUD |
| `sync-config.js` | Supabase URL / anon key config |
| `index.html` | Web shell |
| `ios/BudgetStudio/` | SwiftUI iOS app |
| `supabase/rls.sql` | RLS policies for `budgets` |

## Rules of thumb

- **Never** put the Supabase `service_role` key in client code or this repo’s frontend. Anon key + RLS only.
- Prefer **not** changing budget math / calculation logic unless the user explicitly asks.
- Push / deploy to GitHub Pages **only when the user asks** (or when they note the live URL above).
- Only open source files when implementing a change; start from the docs list above.
