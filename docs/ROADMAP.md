# Roadmap — Budget Studio

**Last updated:** July 9, 2026  
**North star:** Production-ready commercial personal budgeting (web + iOS), acquisition-clean IP, honest scale path.

---

## Now (launch foundation)

- [x] Client security hardening + tests
- [x] Privacy / Terms drafts + links
- [x] RLS SQL + launch checklists
- [x] Proprietary LICENSE + legal/docs pack (this audit)
- [ ] Operator: apply RLS + Auth dashboard settings ([`../LAUNCH_CHECKLIST.md`](../LAUNCH_CHECKLIST.md))
- [ ] Clear dog logo provenance or replace ([`../legal/AI_ASSETS.md`](../legal/AI_ASSETS.md))
- [ ] Trademark search ([`../legal/TRADEMARK.md`](../legal/TRADEMARK.md))
- [ ] Counsel review of legal pages

---

## Next (TestFlight / early commercial)

1. **TestFlight** — internal family → external beta; gather crash/auth feedback.
2. **Self-serve account deletion** — Edge Function with service role **server-side only** + UI confirm.
3. **Host with real CSP headers** — Cloudflare/Netlify/Vercel in front of static assets.
4. **Pin CDN** — exact `@supabase/supabase-js` version; optional vendor ESM.
5. **Self-host Inter** — OFL files + attribution; drop Google Fonts CDN.
6. **In-app OSS licenses** — iOS Settings + optional web About.
7. **Monitoring** — Supabase log drains, uptime check on Pages URL, auth failure alerts.
8. **Backups** — PITR + documented restore drill.

---

## Scale path (toward large user counts)

| Stage | Users (order of) | Changes |
|-------|------------------|---------|
| Family / private | 10s–100s | Current stack OK if RLS + Auth hardened |
| Early commercial | 1k–50k | Paid Supabase, headers host, monitoring, deletion EF, support email SLA |
| Growth | 100k+ | Connection/pool strategy, payload size quotas, abuse detection, status page, possibly BFF for admin |
| Millions | 1M+ | Dedicated infra review, multi-region, formal SDLC, SOC2-minded controls, entity + DPAs, on-call |

A static SPA on GitHub Pages + single Supabase project is a **strong family foundation**, not a million-user production architecture by itself. See scores in [`PRODUCTION_AUDIT.md`](PRODUCTION_AUDIT.md).

---

## Product (optional, non-blocking for security)

- Household / shared budgets with explicit membership model (new RLS design)
- Bank sync (major compliance jump — PCI/GLBA/vendor diligence)
- Push notifications for bill reminders
- WebAuthn / passkeys when Supabase support fits UX

---

## Explicit non-goals (near term)

- Custom Node monolith “just because”
- Putting `service_role` in any client
- Shipping without RLS verified live

---

## Related

- [`PRODUCTION_AUDIT.md`](PRODUCTION_AUDIT.md)
- [`DEPLOYMENT.md`](DEPLOYMENT.md)
- [`../legal/COMPLIANCE_CHECKLIST.md`](../legal/COMPLIANCE_CHECKLIST.md)
