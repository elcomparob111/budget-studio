# Budget Studio

A local-first personal budget app with setup wizard, paycheck view, charts, and CSV/JSON backup.

## Run locally

```bash
npm start
```

Then open [http://localhost:3000](http://localhost:3000).

You can also open `index.html` directly in a browser, but a local server is recommended for PWA features.

## Features

- Guided budget setup with income-based category suggestions
- Monthly and pay-period views
- Category spending charts and cash-flow trends
- Transaction add, edit, and delete
- CSV export and JSON backup/restore
- Dark mode and offline support (PWA)

Data is stored in your browser's `localStorage` only — nothing is sent to a server.
