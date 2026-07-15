# Budget Studio — Launch checklist

Live: https://elcomparob111.github.io/budget-studio/  
Supabase: https://supabase.com/dashboard/project/dhlaqqghjfmgdlkfxlxg  
Details: [docs/SECURITY.md](docs/SECURITY.md) (root [SECURITY.md](SECURITY.md) is a pointer)

## Repo (done in code)

- [x] No `service_role` in client (`npm run security:scan`)
- [x] Client defenses + security tests (`npm test`)
- [x] Privacy / Terms pages linked from auth + Settings
- [x] RLS SQL ready: [`supabase/rls.sql`](supabase/rls.sql)

## Supabase operator steps

> **Status (2026-07-10):** Sections 1–2 applied (RLS, email confirm, password policy). Smoke test found confirm links landing on `https://elcomparob111.github.io` (Pages 404) — **re-check Site URL** is exactly `https://elcomparob111.github.io/budget-studio/` (with path). Web signup now passes `emailRedirectTo` with that path. **Remaining:** re-run smoke test (section 3) after dashboard fix.
>
> **Old emails keep old redirects.** Confirmation / recovery links bake the redirect URL at send time. After fixing Site URL + Redirect URLs, do **not** reuse an old email — resend confirmation (Authentication → Users) or sign up again. Hard-refresh the app first so SW `budget-studio-v31+` is loaded before a new signup.

### 1. Run RLS

1. Open [SQL Editor (new)](https://supabase.com/dashboard/project/dhlaqqghjfmgdlkfxlxg/sql/new)
2. Paste **all** of [`supabase/rls.sql`](supabase/rls.sql) → **Run**
3. Verify (new query → Run):

```sql
select tablename, rowsecurity from pg_tables where schemaname = 'public' and tablename = 'budgets';
select policyname, cmd from pg_policies where tablename = 'budgets';
```

Expect `rowsecurity = true` and four policies (SELECT / INSERT / UPDATE / DELETE).

### 2. Auth settings

| Setting | URL | Action |
| --- | --- | --- |
| URL config | [Auth → URL Configuration](https://supabase.com/dashboard/project/dhlaqqghjfmgdlkfxlxg/auth/url-configuration) | **Site URL** = `https://elcomparob111.github.io/budget-studio/` (WITH `/budget-studio/` — bare root 404s unless the user-site redirect repo is live) · **Redirect URLs** must include that exact URL **and** `https://elcomparob111.github.io/budget-studio/**` (plus `http://localhost:3000/**` for local). If `emailRedirectTo` is not allowlisted, Supabase falls back to Site URL. |
| Email confirm | [Auth → Providers → Email](https://supabase.com/dashboard/project/dhlaqqghjfmgdlkfxlxg/auth/providers) | Enable **Confirm email** for production |
| Password | [Auth → Providers → Email](https://supabase.com/dashboard/project/dhlaqqghjfmgdlkfxlxg/auth/providers) (or Password settings) | Min length **8**; prefer letters + digits (matches app) |
| Rate limits | [Auth → Rate Limits](https://supabase.com/dashboard/project/dhlaqqghjfmgdlkfxlxg/auth/rate-limits) | **Before public publish:** confirm limits are enabled; optionally tighten sign-in / sign-up / recovery below defaults. Fine to leave defaults for family/TestFlight. |
| Attack protection | [Auth → Attack Protection](https://supabase.com/dashboard/project/dhlaqqghjfmgdlkfxlxg/auth/protection) | **Before public publish:** enable CAPTCHA and leaked-password protection if available. Web client lockout in `security.js` is UX-only — not a substitute. |

### 3. Smoke test

- [ ] Sign up with a real email → confirm link works
- [ ] Sign in → budget syncs
- [ ] Second browser/incognito cannot read first user’s data
- [ ] Settings → Delete cloud data removes row; export still works beforehand

## Optional later

- [ ] Host with real CSP/`frame-ancestors` headers (Netlify/Vercel/Cloudflare) — GitHub Pages cannot set them
- [ ] Counsel-reviewed legal copy if you commercialize
