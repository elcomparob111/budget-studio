# Third-Party Licenses — Budget Studio

**Last updated:** July 9, 2026  
**Project license:** Proprietary All Rights Reserved — see [`../LICENSE`](../LICENSE) and [`COPYRIGHT.md`](COPYRIGHT.md).

This NOTICE-style file attributes open-source and font components used by Budget Studio. It does **not** re-license the Owner’s proprietary code.

Run `npm run license:check` for a machine-readable inventory summary.

---

## Web — CDN runtime

### @supabase/supabase-js

| | |
|--|--|
| **License** | MIT |
| **How used** | Dynamic ESM import in `sync.js` from jsDelivr: `https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm` |
| **Pinning** | Major `@2` only (floating within v2) — prefer exact version pin before scale |
| **Copyright** | Copyright (c) Supabase / contributors — see upstream package |

MIT permission notice (summary): free use, modification, and distribution with copyright and permission notice retained; provided “AS IS” without warranty.

### Inter font

| | |
|--|--|
| **License** | SIL Open Font License 1.1 (OFL-1.1) |
| **Author** | Rasmus Andersson / rsms |
| **How used** | Loaded via Google Fonts CSS in `index.html` (`fonts.googleapis.com` / `fonts.gstatic.com`) |
| **CSS** | `font-family: Inter, …` in `styles.css` |
| **Delivery ToS** | Google Fonts Terms of Service also apply to CDN delivery |
| **Recommended** | Self-host OFL `woff2` files under `fonts/` with OFL attribution to reduce Google Fonts ToS/privacy surface |

OFL allows use, study, modification, and redistribution of the font software under OFL terms. Do not sell the font by itself. Reserved font names rules apply if modified. Full OFL text: https://openfontlicense.org/

---

## iOS — Swift Package Manager

Direct dependency (`ios/project.yml`):

| Package | Version (resolved) | License |
|---------|-------------------|---------|
| [supabase-swift](https://github.com/supabase/supabase-swift) | 2.51.0 (`from: 2.5.0`) | MIT |

Transitive (from `Package.resolved`):

| Package | Version | License |
|---------|---------|---------|
| swift-asn1 (Apple) | 1.7.1 | Apache-2.0 |
| swift-clocks (Point-Free) | 1.1.0 | MIT |
| swift-concurrency-extras (Point-Free) | 1.4.0 | MIT |
| swift-crypto (Apple) | 4.5.0 | Apache-2.0 |
| swift-http-types (Apple) | 1.6.0 | Apache-2.0 |
| xctest-dynamic-overlay (Point-Free) | 1.10.1 | MIT |

**App Store note:** Include an in-app “Open Source Licenses” screen (or Settings link) listing the above before or at App Store submission. Apple commonly expects OSS attribution for included libraries.

---

## Platform (not redistributed as project files)

| Item | Notes |
|------|--------|
| Apple SF Symbols | Via `Image(systemName:)` — Apple platform terms |
| System UI fonts (`.rounded`) | Not vendored |
| Vision / LocalAuthentication / Keychain | On-device Apple frameworks |

---

## npm

No runtime or declared `dependencies` / `devDependencies` in `package.json`. Local `npm start` may use ephemeral `npx serve` (not locked in-repo).

---

## No copyleft infection found

No GPL, AGPL, or LGPL packages identified in CDN or SPM trees as of the last sweep ([`../LEGAL_SWEEP.md`](../LEGAL_SWEEP.md)).

---

## Attribution display (recommended)

| Surface | Action |
|---------|--------|
| Web Settings / About | Link to this file or a short “Licenses” page |
| iOS Settings | OSS credits list |
| Repo | Keep this file updated on dependency bumps |
