# Deployment — Budget Studio

**Last updated:** July 9, 2026  

Three surfaces: **GitHub Pages (web)**, **Supabase (Auth + DB)**, **iOS (Xcode / TestFlight)**.

---

## 1. Supabase (required for sync)

Project dashboard: https://supabase.com/dashboard/project/dhlaqqghjfmgdlkfxlxg

1. Run [`../supabase/rls.sql`](../supabase/rls.sql) in SQL Editor (idempotent).
2. Configure Auth per [`SECURITY.md`](SECURITY.md) § Auth settings and [`../LAUNCH_CHECKLIST.md`](../LAUNCH_CHECKLIST.md).
3. Confirm anon key in `sync-config.js` / iOS `SyncConfig` matches **Project Settings → API** publishable key.
4. Never deploy `service_role` to Pages, iOS, or git.

### Backups / DR (operator)

| Control | Recommendation |
|---------|----------------|
| Point-in-time recovery | Enable on paid Supabase plan before commercial users |
| Logical dump | Periodic `pg_dump` or Dashboard backup export to encrypted offline store |
| Key compromise | Rotate anon key + update clients; rotate service_role if ever exposed |
| Region outage | Accept multi-hour RTO on free/static stack; document in status page later |

---

## 2. Web — GitHub Pages

Live: https://elcomparob111.github.io/budget-studio/

Typical flow:

1. Merge to `main` (or the branch configured for Pages).
2. GitHub Actions / Pages publishes static files from repo root (or `/docs` if configured — this project uses root assets).
3. Users may need a refresh for service worker updates. Bump `CACHE` in `sw.js` **only when runtime web assets change** (not for docs-only commits).

### Local

```bash
npm start
# http://localhost:3000
```

### Optional hosts (better security headers)

Configs already in repo (Pages ignores them):

- [`../netlify.toml`](../netlify.toml)
- [`../vercel.json`](../vercel.json)
- [`../public/_headers`](../public/_headers)

Point DNS / project to the same static files; update Supabase Auth Site URL + redirect allowlist to the new origin.

---

## 3. iOS

```bash
cd ios
open BudgetStudio.xcodeproj
# or: xcodegen generate && open …
```

| Setting | Value |
|---------|--------|
| Bundle ID | `com.budgetstudio.app` |
| Team | Set in Xcode (`DEVELOPMENT_TEAM` in `project.yml`) |
| Min iOS | 17.0 |
| Backend | Same Supabase project as web |

Release path: Archive → TestFlight → App Store. See [`../legal/RELEASE_CHECKLIST.md`](../legal/RELEASE_CHECKLIST.md) and [`../ios/README.md`](../ios/README.md).

---

## 4. Secrets & CI

| Secret | Where |
|--------|-------|
| Anon key | Public in client (OK) |
| Service role | Supabase Dashboard / CI secrets only — **never** client |
| Apple signing | Local Keychain / CI secrets |

`.gitignore` excludes `outputs/`, Supabase CLI temp, iOS DerivedData, `.env*` patterns, etc.

Suggested CI (future): `npm test && npm run security:scan && npm run license:check` on PR.

---

## 5. Rollback

| Surface | Rollback |
|---------|----------|
| Web | Revert git commit on Pages branch; bump SW if needed |
| DB | Restore from Supabase backup / PITR (test before you need it) |
| iOS | Previous TestFlight build; App Store phased release |

---

## Related

- [`ARCHITECTURE.md`](ARCHITECTURE.md)
- [`SECURITY.md`](SECURITY.md)
- [`ROADMAP.md`](ROADMAP.md)
- [`../legal/RELEASE_CHECKLIST.md`](../legal/RELEASE_CHECKLIST.md)
