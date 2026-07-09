# Budget Studio

A personal budget app with setup wizard, paycheck view, charts, cloud sync, and CSV/JSON backup.

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

## Features

- Guided budget setup with income-based category suggestions
- Monthly and pay-period views
- Category spending charts and cash-flow trends
- Transaction add, edit, and delete
- Cloud sync with email/password accounts (Supabase)
- CSV export and JSON backup/restore
- Dark mode and offline support (PWA on web)
