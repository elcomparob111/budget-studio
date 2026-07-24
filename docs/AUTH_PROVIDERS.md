# Auth providers — Apple, Google, passkeys, CAPTCHA

Free-plan setup for Budget Studio. **Leaked-password protection stays Pro-only** and is out of scope here.

Live app: https://elcomparob111.github.io/budget-studio/  
Dashboard: https://supabase.com/dashboard/project/dhlaqqghjfmgdlkfxlxg/auth/providers

---

## 1. Redirect URLs (do this first)

[Auth → URL Configuration](https://supabase.com/dashboard/project/dhlaqqghjfmgdlkfxlxg/auth/url-configuration)

Keep existing Site URL + allowlist, and **add**:

| Redirect URL | Why |
| --- | --- |
| `https://elcomparob111.github.io/budget-studio/` | Web OAuth return (already required) |
| `https://elcomparob111.github.io/budget-studio/**` | Web OAuth / PKCE variants |
| `http://localhost:3000/**` | Local web |
| `budgetstudio://auth-callback` | iOS Google OAuth (ASWebAuthenticationSession) |

---

## 2. Sign in with Apple

### iOS (native — required for the app button)

1. Apple Developer → Identifiers → App ID `com.budgetstudio.app` → enable **Sign in with Apple**.
2. Xcode capability is already in `BudgetStudio.entitlements` (`com.apple.developer.applesignin`).
3. Supabase → **Authentication → Providers → Apple** → Enable.
4. Under **Client IDs**, add: `com.budgetstudio.app`  
   (Native iOS does **not** need Services ID / secret key.)

### Web (OAuth — optional but recommended)

Apple requires a **Services ID** + signing key (`.p8`) that you rotate every **6 months**.

1. Create Services ID (e.g. `com.budgetstudio.app.web`) linked to the App ID.
2. Website URLs:
   - Domains: `dhlaqqghjfmgdlkfxlxg.supabase.co`
   - Return URL: `https://dhlaqqghjfmgdlkfxlxg.supabase.co/auth/v1/callback`
3. Create a Sign in with Apple **Key** (`.p8`), note Key ID + Team ID.
4. In Supabase Apple provider:
   - Services ID as the **first** Client ID (web OAuth uses the first entry).
   - Also list `com.budgetstudio.app` for native.
   - Paste secret generated from the `.p8` (dashboard has a generator).
5. Calendar reminder: rotate secret every 6 months.

Until web Apple is configured, the web “Continue with Apple” button will fail at Apple/Supabase — iOS native still works once Client IDs include the bundle ID.

---

## 3. Google

1. [Google Cloud Console](https://console.cloud.google.com/) → create OAuth client(s):
   - **Web application** for the PWA  
     Authorized redirect URI: `https://dhlaqqghjfmgdlkfxlxg.supabase.co/auth/v1/callback`
   - Optional iOS client if you later switch off browser OAuth.
2. Supabase → **Authentication → Providers → Google** → Enable → paste Client ID + Client Secret (web).
3. Web and iOS both use Supabase OAuth; iOS returns via `budgetstudio://auth-callback`.

---

## 4. Passkeys (WebAuthn)

1. Supabase → **Authentication → Passkeys** → Enable.
2. Relying Party:
   - **Display name:** `Budget Studio`
   - **RP ID:** `elcomparob111.github.io` (bare host — no path)
   - **Origins:** `https://elcomparob111.github.io`  
     (optional: `http://localhost:3000` for local)
3. **Do not change RP ID** after users enroll — existing passkeys break.

### iOS Associated Domains (for passkeys in the app)

Apple requires `apple-app-site-association` at the **domain root**:

`https://elcomparob111.github.io/.well-known/apple-app-site-association`

Project Pages (`/budget-studio/`) cannot serve that path. Host the file from [`../well-known/apple-app-site-association`](../well-known/apple-app-site-association) on a **user/org GitHub Pages site** at `elcomparob111.github.io` (separate `elcomparob111.github.io` repo), or move the app to a custom domain and serve AASA there.

Until AASA is live, **web passkeys** still work; **iOS passkey** registration/sign-in may fail Associated Domains checks.

---

## 5. Rate limits + CAPTCHA (Free plan)

### Rate limits

[Auth → Rate Limits](https://supabase.com/dashboard/project/dhlaqqghjfmgdlkfxlxg/auth/rate-limits) — confirm defaults (or tighten) before public publish.

### CAPTCHA (Cloudflare Turnstile recommended)

1. Create a Turnstile widget at Cloudflare → copy **Site key** + **Secret key**.
2. Supabase → **Authentication → Attack Protection** → Enable CAPTCHA → provider Turnstile → paste **Secret**.
3. Put the **Site key** in [`../sync-config.js`](../sync-config.js) as `captchaSiteKey`.
4. Redeploy / hard-refresh the PWA. The auth form shows Turnstile and sends `captchaToken` on email sign-in / sign-up / reset.

Do **not** enable CAPTCHA in the dashboard without setting `captchaSiteKey`, or email auth will reject submissions.

**Skipped (Pro):** leaked-password protection.

---

## 6. Smoke test

- [ ] Web: Continue with Google → lands back on `/budget-studio/` signed in
- [ ] Web: Continue with Apple (after Services ID setup)
- [ ] Web: Sign in with passkey (after registering one in Settings while signed in)
- [ ] iOS: Sign in with Apple
- [ ] iOS: Continue with Google → returns to app
- [ ] iOS: Add passkey (after AASA is hosted) → Sign in with passkey
- [ ] Email/password still works
- [ ] CAPTCHA appears when `captchaSiteKey` is set
