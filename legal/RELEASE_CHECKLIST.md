# Release Checklist — Budget Studio

**Last updated:** July 9, 2026  
**Live web:** https://elcomparob111.github.io/budget-studio/  
**Ops detail:** [`../LAUNCH_CHECKLIST.md`](../LAUNCH_CHECKLIST.md)

Use this for each production cut (web and/or iOS). Mark only what you verified.

---

## Pre-release (every cut)

### Repo hygiene

- [ ] `git status` clean of secrets / personal `outputs/`
- [ ] `npm test` passes
- [ ] `npm run security:scan` passes
- [ ] `npm run license:check` passes
- [ ] `npm run security:audit` passes
- [ ] No `service_role` in client configs
- [ ] `LICENSE` + `legal/` docs present
- [ ] Privacy / Terms still accurate for this build

### Supabase (production project)

- [ ] [`supabase/rls.sql`](../supabase/rls.sql) applied; `rowsecurity = true`; four policies
- [ ] Auth Site URL + redirect allowlist match live origin
- [ ] Email confirm enabled (prod)
- [ ] Password min length ≥ 8; letters + digits preferred
- [ ] Auth rate limits enabled (tighten sign-in / sign-up / recovery before public launch; defaults OK for family/TestFlight)
- [ ] Attack protection: CAPTCHA enabled before public publish (client lockout in `security.js` is UX-only)
- [ ] Leaked-password protection — **Pro-plan only**; N/A on the current plan. Revisit on upgrade; advisor stays WARN until then.
- [ ] Smoke: signup → confirm → sync → isolation → delete cloud data → export

### Web (GitHub Pages)

- [ ] Push to `main` (or Pages branch) deployed
- [ ] Hard-refresh / SW update: users get new assets (`sw.js` cache bump **only if** runtime assets changed)
- [ ] Auth, sync, offline shell, privacy/terms links work on live URL
- [ ] Optional: deploy behind Netlify/Vercel/Cloudflare for real CSP headers
- [ ] Optional: Hallmark skill ([`.agents/skills/hallmark`](../.agents/skills/hallmark)) for landing/legal polish or `hallmark audit` before public publish — do not casually redesign the live PWA

### iOS

- [ ] Archive with correct team / bundle id `com.budgetstudio.app`
- [ ] Same Supabase anon project as web
- [ ] Face ID / camera / photos strings still accurate
- [ ] TestFlight internal → external → App Store
- [ ] App Privacy labels + support/privacy URLs

---

## Post-release

- [ ] Tag release (`vX.Y.Z`) optional
- [ ] Note known issues in [`../docs/ROADMAP.md`](../docs/ROADMAP.md)
- [ ] Monitor Supabase Auth errors / DB size
- [ ] Backup restore drill within 90 days of first commercial users

---

## Do not ship if

- RLS disabled or policies missing
- `service_role` anywhere in client or public repo
- Privacy/Terms removed or unlinked
- Password recovery redirect points at untrusted origin

---

## Related

- [`COMPLIANCE_CHECKLIST.md`](COMPLIANCE_CHECKLIST.md)
- [`../docs/DEPLOYMENT.md`](../docs/DEPLOYMENT.md)
- [`../docs/PRODUCTION_AUDIT.md`](../docs/PRODUCTION_AUDIT.md)
