# Budget Studio — Security

Launch checklist for the static PWA + Supabase architecture. Password hashing, session issuance, and Auth rate limits are **Supabase Auth** responsibilities. This app ships only the **anon / publishable** key.

Live site: https://elcomparob111.github.io/budget-studio/

---

## Architecture threats (honest)

| Area | Reality |
| --- | --- |
| Password hashing | Supabase Auth (bcrypt). Not implementable in a static frontend. |
| HttpOnly session cookies | Supabase JS stores JWTs in local storage / memory. XSS can steal tokens — mitigate XSS hard (CSP + `escapeHtml`). |
| Server rate limits | Enable in Supabase Auth. Client lockout in `security.js` is UX-only and bypassable. |
| GitHub Pages headers | Pages does **not** support custom `Content-Security-Policy` / HSTS response headers. Meta CSP is best-effort; `frame-ancestors` / HSTS must come from the host. Pages already serves HTTPS. |
| Anon key | Public by design. **RLS is mandatory.** Never put `service_role` in the repo or app. |

---

## Pre-launch checklist (do these in order)

### 1. Confirm no service role in the repo

```bash
npm run security:scan
# or: ./scripts/security-scan.sh
```

`sync-config.js` and iOS `SyncConfig` must contain only the **anon / publishable** key.

### 2. Run RLS SQL

In Supabase → **SQL Editor**, run the contents of [`supabase/rls.sql`](supabase/rls.sql) (same policies as [`supabase-schema.sql`](supabase-schema.sql)).

Verify:

```sql
select tablename, rowsecurity from pg_tables where tablename = 'budgets';
select policyname, cmd from pg_policies where tablename = 'budgets';
```

Expect `rowsecurity = true` and SELECT/INSERT/UPDATE/DELETE policies scoped to `auth.uid() = user_id`.

### 3. Auth settings (Supabase Dashboard → Authentication)

1. **Providers** → Email enabled; disable unused providers.
2. **Email** → enable **Confirm email** for production (recommended).
3. **Password** → minimum length **8**; require letters + digits if the UI offers it (match client rules in `security.js`).
4. **Rate limits** → keep defaults or tighten sign-in / sign-up / recovery limits.
5. **URL configuration**
   - Site URL: `https://elcomparob111.github.io/budget-studio/`
   - Redirect URLs allowlist:
     - `https://elcomparob111.github.io/budget-studio/`
     - `https://elcomparob111.github.io/budget-studio/**`
     - `http://localhost:3000/**` (dev only)
6. **Attack protection** — enable CAPTCHA / leaked-password protection if available on your plan.

### 4. API / CORS (Supabase Dashboard → Settings → API + Auth URL config)

Allowed browser origins for this app:

- `https://elcomparob111.github.io`
- `http://localhost:3000` (local `npm start`)

Supabase Auth redirect allowlist (step 3) is the critical control for password-recovery links.

### 5. GitHub Pages limits

- HTTPS is provided by GitHub Pages (treat as HSTS at the CDN edge; you cannot set a custom HSTS header on Pages).
- Meta tags in `index.html` set CSP, Referrer-Policy, and Permissions-Policy best-effort.
- Meta CSP **cannot** enforce `frame-ancestors` / `X-Frame-Options`. If clickjacking is a concern, host behind Cloudflare/Netlify/Vercel and use [`public/_headers`](public/_headers), [`vercel.json`](vercel.json), or [`netlify.toml`](netlify.toml).

### 6. Privacy / terms

[`privacy.html`](privacy.html) and [`terms.html`](terms.html) are live, linked from Settings and the auth screen. Contact: `1munoz.roberto@gmail.com`. Have counsel review before any commercial launch.

Crisp click-path: [`LAUNCH_CHECKLIST.md`](LAUNCH_CHECKLIST.md).

### 7. Account deletion

Settings → **Delete cloud data** removes the user’s `budgets` row (RLS) and signs out. Full Auth user deletion requires Supabase Dashboard → Authentication → Users (or a privileged Edge Function — do **not** put `service_role` in the client).

### 8. iOS notes

- Uses the same anon key + `budgets` table; RLS still applies.
- Keep Keychain/session handling via supabase-swift defaults.
- Do not log budget payloads or passwords.
- SPM: Supabase Swift and its transitive deps — review advisories when upgrading packages in Xcode.

---

## Client defenses already in the app

- `escapeHtml` for all user-controlled HTML rendering
- Password strength + email validation before signup / password update
- SessionStorage auth cooldown after repeated failures
- Generic auth error messages (no “user exists” vs “wrong password” leak where avoidable)
- Logout clears **all** `budget-studio-state-v7:uid:*` local caches (shared-device hygiene)
- Cloud fetch/push asserts live `auth.uid()` matches the requested user id **and** refuses missing session
- Cloud/import payloads are schema-sanitized (whitelist fields, strip `__proto__`, cap array sizes, strip `<>` from names)
- Import rejects files over 2 MB and ignores any `user_id` in the JSON (ownership is session-only)
- Password-recovery session does not load/sync budget data until the new password is saved
- Service worker caches only same-origin static assets (never Supabase/API JSON)
- Safe logger redacts financial / secret fields
- CSP meta + security meta tags
- iOS: session ownership check on fetch/push; UserDefaults uid caches cleared on sign-out

---

## Remaining risks (cannot fully fix in a static SPA)

| Risk | Mitigation |
| --- | --- |
| XSS → session token theft | Keep CSP + `escapeHtml`; prefer hosting with real CSP headers (Netlify/Vercel/`_headers`) |
| Client auth lockout bypass | Enable Supabase Auth rate limits + CAPTCHA |
| Shared browser without logout | Always sign out; caches are cleared on logout but a live session is still the user’s |
| Full Auth user deletion | Dashboard or privileged Edge Function — never `service_role` in the client |
| iOS Face ID stores email/password in Keychain | Device-only Keychain item; user can disable in Settings |
| Server-side payload size / rate limits | Configure Supabase / Postgres limits in the dashboard |

---

## Tests

```bash
npm test
```

Runs `tests/security.test.js` (escapeHtml, validators, ownership check, payload sanitization, import size, rate-limit helper, auth error sanitization).
