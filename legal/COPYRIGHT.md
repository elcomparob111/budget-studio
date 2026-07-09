# Copyright — Budget Studio

**Owner:** Roberto Munoz / Budget Studio  
**Year:** 2026  
**Contact:** 1munoz.roberto@gmail.com  
**Last updated:** July 9, 2026

---

## License choice

| Option considered | Decision |
|-------------------|----------|
| MIT / permissive OSS | Rejected for commercial / acquisition path — would allow unrestricted reuse of product code. |
| **All Rights Reserved / proprietary** | **Selected.** See root [`LICENSE`](../LICENSE) and [`legal/LICENSE`](LICENSE). |

**Rationale:** Budget Studio is intended as a commercial product that may be acquired. A proprietary license keeps ownership clear for diligence, assignment, and exclusive licensing. Third-party open-source components remain under their own licenses (see [`THIRD_PARTY_LICENSES.md`](THIRD_PARTY_LICENSES.md)).

This is not legal advice. Counsel should review before any sale, fundraising, or App Store commercial listing.

---

## What is owned

Unless noted otherwise, the Owner claims copyright in:

- Web PWA source (`app.js`, `sync.js`, `security.js`, `styles.css`, `index.html`, service worker, etc.)
- iOS SwiftUI application under `ios/BudgetStudio/`
- Original documentation under `docs/` and `legal/` (except third-party license texts)
- Original geometric favicon (`favicon.svg`)
- Product name usage as a brand (see [`TRADEMARK.md`](TRADEMARK.md) — clearance not completed)
- Privacy and Terms page drafts (`privacy.html`, `terms.html`) as original short-form copy

---

## What is not solely owned / needs care

| Item | Status | Doc |
|------|--------|-----|
| Dog app icon (AI-stylized) | Provenance incomplete | [`AI_ASSETS.md`](AI_ASSETS.md) |
| Inter font | SIL OFL 1.1 | [`THIRD_PARTY_LICENSES.md`](THIRD_PARTY_LICENSES.md) |
| Supabase JS / Swift + transitive SPM | MIT / Apache-2.0 | [`THIRD_PARTY_LICENSES.md`](THIRD_PARTY_LICENSES.md) |
| Apple SF Symbols / system fonts | Apple platform terms | Not redistributed as files |
| Google Fonts CDN delivery | Google Fonts ToS | Prefer self-host Inter |

---

## Assignment / acquisition readiness

For diligence, keep:

1. This file + proprietary `LICENSE`
2. [`AI_ASSETS.md`](AI_ASSETS.md) updated when logo rights are cleared
3. [`THIRD_PARTY_LICENSES.md`](THIRD_PARTY_LICENSES.md) current with dependency upgrades
4. Contributor / contractor IP assignment agreements if anyone else writes code
5. Counsel-reviewed Privacy Policy and Terms before paid launch

---

## Related

- Full inventory sweep: [`../LEGAL_SWEEP.md`](../LEGAL_SWEEP.md)
- Compliance checklist: [`COMPLIANCE_CHECKLIST.md`](COMPLIANCE_CHECKLIST.md)
