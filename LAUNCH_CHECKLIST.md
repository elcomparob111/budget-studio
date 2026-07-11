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

> **Status (2026-07-10):** Sections 1–2 applied and verified via dashboard: RLS enabled with 4 policies confirmed; Site URL + 3 redirect URLs set; email confirmation ON; password min length 8 with letters+digits. Leaked-password protection unavailable on Free plan; CAPTCHA left off until clients integrate a captcha widget; rate limits at defaults. **Remaining:** smoke test (section 3).

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
| URL config | [Auth → URL Configuration](https://supabase.com/dashboard/project/dhlaqqghjfmgdlkfxlxg/auth/url-configuration) | **Site URL** = `https://elcomparob111.github.io/budget-studio/` · Redirect allowlist: that URL, `https://elcomparob111.github.io/budget-studio/**`, and `http://localhost:3000/**` for local dev |
| Email confirm | [Auth → Providers → Email](https://supabase.com/dashboard/project/dhlaqqghjfmgdlkfxlxg/auth/providers) | Enable **Confirm email** for production |
| Password | [Auth → Providers → Email](https://supabase.com/dashboard/project/dhlaqqghjfmgdlkfxlxg/auth/providers) (or Password settings) | Min length **8**; prefer letters + digits (matches app) |
| Rate limits | [Auth → Rate Limits](https://supabase.com/dashboard/project/dhlaqqghjfmgdlkfxlxg/auth/rate-limits) | Keep defaults or tighten sign-in / sign-up / recovery |
| Attack protection | [Auth → Attack Protection](https://supabase.com/dashboard/project/dhlaqqghjfmgdlkfxlxg/auth/protection) | Enable CAPTCHA / leaked-password protection if available |

### 3. Smoke test

- [ ] Sign up with a real email → confirm link works
- [ ] Sign in → budget syncs
- [ ] Second browser/incognito cannot read first user’s data
- [ ] Settings → Delete cloud data removes row; export still works beforehand

## Optional later

- [ ] Host with real CSP/`frame-ancestors` headers (Netlify/Vercel/Cloudflare) — GitHub Pages cannot set them
- [ ] Counsel-reviewed legal copy if you commercialize
