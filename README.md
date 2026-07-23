# Morph — AI Physique Coach

An iOS app that turns weekly physique photos into structured, actionable coaching. Users submit four photos (front / back / left / right), and Claude's vision model returns scored analysis — symmetry, muscular development, leanness, proportions — plus personalized macro targets, a training split, and week-over-week progress tracking.

Built with SwiftUI, StoreKit 2, Swift Charts, and the Anthropic API.

## Features

- **AI physique analysis** — 4-angle photo assessment scored across five dimensions, with estimated body fat %, strength/weakness breakdown, and a weekly focus
- **Personalized nutrition** — TDEE calculated client-side (Mifflin-St Jeor) and passed to the model for grounded calorie + protein/carb/fat targets and meal-timing guidance
- **Training plans** — suggested split with a full 7-day schedule, tailored to what the model sees in the photos
- **Progress tracking** — score and weight trend charts (Swift Charts), week-over-week score deltas, streak tracking, and goal-weight progress
- **Before/after compare** — side-by-side photo comparison across any two check-ins, with angle switching and delta stats
- **Freemium subscriptions** — StoreKit 2 with transaction listener; free tier (1 check-in/week) and Pro (daily check-ins), monthly/yearly products with a local StoreKit config for simulator testing
- **Shareable results** — branded score cards rendered with `ImageRenderer` for social sharing
- **Quality of life** — kg/lbs units, weekly reminder notifications, haptics, animated score rings, dark athletic design system

## Architecture

```
morph/
├── morphApp.swift            App entry — injects Auth + Subscription state
├── Models.swift              Codable domain models w/ tolerant decoding
├── DesignSystem.swift        Colors, typography, spacing, reusable components
├── ClaudeAIService.swift     AI pipeline: prompt build → proxy call → JSON parse
├── *ViewModel.swift          MVVM state (auth, check-ins, subscriptions)
└── *View.swift               SwiftUI feature views
```

- **MVVM** with `ObservableObject` view models and environment injection
- **File-based persistence** for check-ins (photos made UserDefaults unviable); tolerant `Codable` decoding so schema evolution never wipes user history
- **Images downscaled on ingest** (1200px JPEG) to bound both local storage and API payload size

## Security design

- **No API keys ship in the app.** All Anthropic calls route through a Supabase Edge Function proxy; the API key lives in server-side secrets. Model choice and token limits are pinned server-side so clients can't alter them.
- **Prompt-injection hardening.** The system prompt enforces scope (physique analysis only), rejects non-physique images via a structured error, and instructs the model to ignore adversarial instructions embedded in user notes or photos.
- Backend endpoint values are kept in a gitignored `Secrets.swift` (see `Secrets.example.swift`).

## Building

1. Open `morph.xcodeproj` in Xcode 16+ (iOS 17+ target)
2. Copy `Secrets.example.swift` → `morph/Secrets.swift` and point it at your own AI proxy (a reference Supabase Edge Function is in `morph/SETUP.md`)
3. Select an iPhone simulator and run — subscriptions work out of the box via the bundled `Morph.storekit` configuration

## License

Copyright © 2026 Elmar Rasho. All rights reserved.

This source code is published for portfolio review. No permission is granted to copy, modify, distribute, or use it in derivative works or commercial products.
