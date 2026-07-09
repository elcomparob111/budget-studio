# Privacy Checklist — Budget Studio

**Last updated:** July 9, 2026  
**Public policy:** [`../privacy.html`](../privacy.html)  
**Contact:** 1munoz.roberto@gmail.com

Not legal advice. Align product behavior with the published policy before commercial claims (GDPR/CCPA marketing, paid plans, etc.).

---

## Data map (current architecture)

| Data | Where | Purpose | Retention |
|------|-------|---------|-----------|
| Email + password hash | Supabase Auth | Account | Until Auth user deleted |
| Display name (optional) | Auth `user_metadata` | UI | Until updated/deleted |
| Budget JSON (categories, txns, notes) | Postgres `budgets.state` | Sync | Until row deleted |
| Local cache | Browser localStorage / iOS UserDefaults | Offline | Cleared on logout (web); device until cleared |
| Face ID credentials (optional) | iOS Keychain | Fast unlock | User-controlled |
| Receipt images (OCR) | On-device Vision; not designed as cloud store | Txn assist | Device only |

**Not collected:** bank credentials, SSN, payment cards, ad trackers (per current product).

---

## Checklist

### Policy & notices

- [x] Public Privacy Policy page live and linked from auth + Settings
- [x] Terms of Use live and cross-linked
- [ ] Counsel review of Privacy + Terms for commercial / multi-jurisdiction use
- [ ] Cookie / similar-tech statement if you add analytics (currently no ad cookies; localStorage is functional storage — disclose if expanding)
- [ ] Google Fonts CDN privacy note (fonts request may expose IP to Google) — mitigate by self-hosting Inter

### Rights & user controls

- [x] Export CSV / JSON from Settings
- [x] Delete cloud budget row (Settings → Delete cloud data) + sign out
- [ ] Self-serve **full Auth user deletion** (today: operator email or Dashboard; Edge Function with service role server-side only)
- [ ] Document SLA for deletion requests (e.g. respond within 30 days)
- [ ] Process for access / correction requests via contact email

### Processors

- [x] Supabase named in Privacy Policy
- [ ] Review Supabase DPA / subprocessors for your plan
- [ ] GitHub Pages as static host — no budget JSON intended on Pages; confirm no accidental logging of PII in Issues/Actions
- [ ] If moving to Netlify/Vercel/Cloudflare: update policy with new processors

### Children / sensitive

- [ ] Confirm not directed at children under 13 (COPPA) / under 16 (relevant EU rules) — add age gate or statement if needed
- [ ] No special-category data intended; notes fields could contain sensitive text — keep RLS + export/delete strong

### iOS App Privacy

- [ ] App Store Connect privacy answers match: Account Info (email), User Content (budget data), no tracking
- [ ] Face ID / Camera / Photos usage strings accurate (`project.yml` Info.plist keys)

### Retention & backups

- [ ] Define backup retention (Supabase PITR / daily dumps) and whether deleted users remain in backups for N days
- [ ] Document operator access to production DB (who, when, why)

---

## Gaps called out in production audit

| Gap | Severity | Safest fix |
|-----|----------|------------|
| No self-serve Auth account deletion | Medium | Privileged Edge Function + confirm UI; never put `service_role` in client |
| DIY legal pages | Medium | Counsel review before paid launch |
| Google Fonts CDN | Low–Medium | Self-host Inter |
| Operator is individual (not company) | Low (disclosure) | Update policy when entity forms |

---

## Related

- [`COMPLIANCE_CHECKLIST.md`](COMPLIANCE_CHECKLIST.md)
- [`../docs/SECURITY.md`](../docs/SECURITY.md)
- [`../docs/PRODUCTION_AUDIT.md`](../docs/PRODUCTION_AUDIT.md)
