# Budget Studio — iOS App

Native SwiftUI iPhone/iPad app for Budget Studio, rebuilt with Apple-style UI patterns:

- **Tab bar navigation** — Overview, Activity, Settings
- **Native lists & sheets** — add/edit transactions with swipe-to-delete
- **Grouped settings** — category budgets live on their own screen, not the dashboard
- **Supabase sync** — same accounts and cloud data as the web app
- **Dog logo** — your AI-stylized app icon on sign-in and home screen

## Requirements

1. **Xcode 16+** from the Mac App Store (full Xcode, not just Command Line Tools)
2. An Apple ID (free) for running on your iPhone, or the iOS Simulator

## Open & run

```bash
cd ios
open BudgetStudio.xcodeproj
```

In Xcode:

1. Select the **BudgetStudio** scheme
2. Choose an **iPhone** or **iPad** simulator, or your plugged-in device (Personal Team is fine)
3. Press **Run** (▶)

On iPad, content uses a readable max width with multi-column metric cards — not a stretched phone layout.

First launch shows sign-in. Use the same email/password as the web app — your budget syncs automatically.

## Project layout

```
ios/
  project.yml              # XcodeGen config (regenerate with `xcodegen generate`)
  BudgetStudio/
    BudgetStudioApp.swift
    Design/AppTheme.swift
    Models/BudgetModels.swift
    Services/               # Supabase sync + budget math
    Views/                  # SwiftUI screens
    Assets.xcassets/        # App icon + dog logo
```

## Regenerate Xcode project

If you edit `project.yml` or add Swift files:

```bash
brew install xcodegen   # once
cd ios && xcodegen generate
```

## TestFlight (family testing)

**Requires** a paid [Apple Developer Program](https://developer.apple.com/programs/enroll/) membership ($99/year). A free Personal Team cannot upload to TestFlight.

1. Enroll and wait for approval (often same day, sometimes longer)
2. In Xcode → target **BudgetStudio** → **Signing & Capabilities**: switch Team from Personal to your paid team (keep Automatic signing)
3. At [App Store Connect](https://appstoreconnect.apple.com): **My Apps → + → New App** — bundle ID `com.budgetstudio.app`, name Budget Studio
4. In Xcode: scheme **BudgetStudio**, destination **Any iOS Device**, then **Product → Archive** → **Distribute App → App Store Connect → Upload**
5. In App Store Connect → **TestFlight**: wait for processing, answer export compliance if asked (app uses only standard HTTPS), then invite family by email under Internal or External testing

## Web app

The GitHub Pages site at https://elcomparob111.github.io/budget-studio/ remains available. The iOS app shares the same Supabase backend.
