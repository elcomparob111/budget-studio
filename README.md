# Budget Studio

A personal budget app with setup wizard, paycheck view, charts, cloud sync, and CSV/JSON backup.

**License:** Proprietary — All Rights Reserved ([`LICENSE`](LICENSE), [`legal/COPYRIGHT.md`](legal/COPYRIGHT.md)).

## iOS app (native)

A SwiftUI iPhone app lives in [`ios/`](ios/). It uses the same Supabase accounts and sync as the web version, with a rebuilt native Apple-style UI (tab bar, sheets, grouped lists).

**You need full Xcode from the Mac App Store** to build and run it:

```bash
cd ios
open BudgetStudio.xcodeproj
```

See [`ios/README.md`](ios/README.md) for details.

## Web app

### Run locally

```bash
npm start
```

Then open [http://localhost:3000](http://localhost:3000).

Live site: https://elcomparob111.github.io/budget-studio/

You can also open `index.html` directly in a browser, but a local server is recommended for PWA features.

### Privacy & terms

- [Privacy Policy](privacy.html)
- [Terms of Use](terms.html)

### Security & quality checks

```bash
npm test
npm run security:scan
npm run security:audit
npm run license:check
```

See [`docs/SECURITY.md`](docs/SECURITY.md) and [`LAUNCH_CHECKLIST.md`](LAUNCH_CHECKLIST.md).

## Features

- Guided budget setup with income-based category suggestions
- Monthly and pay-period views
- Category spending charts and cash-flow trends
- Transaction add, edit, and delete
- Cloud sync with email/password accounts (Supabase)
- CSV export and JSON backup/restore
- Dark mode and offline support (PWA on web)

## Documentation

| Doc | Description |
|-----|-------------|
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | System design (Pages + Supabase + iOS) |
| [`docs/SECURITY.md`](docs/SECURITY.md) | Security checklist and defenses |
| [`docs/API.md`](docs/API.md) | Supabase tables / Auth as the API |
| [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) | Deploy web, Supabase, iOS |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | TestFlight, scale, monitoring |
| [`docs/PRODUCTION_AUDIT.md`](docs/PRODUCTION_AUDIT.md) | Production readiness audit + scores |
| [`legal/`](legal/) | LICENSE, copyright, AI assets, compliance |
| [`LEGAL_SWEEP.md`](LEGAL_SWEEP.md) | Copyright/license inventory sweep |
