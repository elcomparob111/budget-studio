# Compliance Checklist — Budget Studio

**Last updated:** July 9, 2026  
**Audience:** Founder + counsel before commercial release / acquisition diligence.

Not legal advice. Check items as completed; leave unchecked until verified.

---

## Intellectual property

- [x] Proprietary `LICENSE` (All Rights Reserved) at repo root + `legal/LICENSE`
- [x] [`COPYRIGHT.md`](COPYRIGHT.md) documents ownership and license choice
- [x] [`THIRD_PARTY_LICENSES.md`](THIRD_PARTY_LICENSES.md) inventories CDN + SPM
- [x] [`AI_ASSETS.md`](AI_ASSETS.md) records dog logo gap (asset retained)
- [ ] Dog logo generator + commercial terms archived
- [ ] Trademark clearance search for “Budget Studio” ([`TRADEMARK.md`](TRADEMARK.md))
- [ ] In-app / Settings OSS attribution screen (iOS + optional web)
- [ ] Self-host Inter (OFL) or document acceptance of Google Fonts CDN
- [ ] Pin `@supabase/supabase-js` to exact CDN version
- [ ] Contributor / contractor IP assignment if others write code
- [ ] Counsel review of Privacy + Terms before paid launch

## Privacy & data protection

See [`PRIVACY_CHECKLIST.md`](PRIVACY_CHECKLIST.md).

## Security & infrastructure

- [x] Client ships anon key only (`npm run security:scan`)
- [x] RLS SQL prepared ([`../supabase/rls.sql`](../supabase/rls.sql))
- [ ] RLS verified live in Supabase project
- [ ] Supabase Auth: email confirm, password policy, rate limits, redirect allowlist
- [ ] CAPTCHA / leaked-password protection if plan allows
- [ ] Prefer host with real CSP + `frame-ancestors` (not GitHub Pages alone) for commercial
- [ ] Backup / PITR strategy documented and tested
- [ ] Incident contact + response outline ([`../docs/SECURITY.md`](../docs/SECURITY.md))

## Commercial / App Store

- [ ] Privacy Nutrition Labels / App Privacy details match actual collection
- [ ] Export compliance / encryption questionnaire (`ITSAppUsesNonExemptEncryption` currently false)
- [ ] Age rating / content declarations accurate
- [ ] Support URL + privacy URL live and linked
- [ ] TestFlight then App Store review

## Acquisition hygiene

- [ ] Cap table / entity formation (if incorporating)
- [ ] Customer data inventory + DPA with Supabase reviewed
- [ ] No `service_role` in git history of client apps (scan periodically)
- [ ] Production audit current ([`../docs/PRODUCTION_AUDIT.md`](../docs/PRODUCTION_AUDIT.md))

---

## Related docs

| Doc | Path |
|-----|------|
| Legal sweep | [`../LEGAL_SWEEP.md`](../LEGAL_SWEEP.md) |
| Launch (ops) | [`../LAUNCH_CHECKLIST.md`](../LAUNCH_CHECKLIST.md) |
| Release | [`RELEASE_CHECKLIST.md`](RELEASE_CHECKLIST.md) |
| Privacy | [`PRIVACY_CHECKLIST.md`](PRIVACY_CHECKLIST.md) |
