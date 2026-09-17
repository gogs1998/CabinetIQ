# CabinetIQ

CabinetIQ is a private life-admin vault for iPhone. Scan an MOT, insurance policy, mortgage letter, or bill. It stays on the device, gets classified into Car / Home / Life, and CabinetIQ reminds you before it lapses. Then you can ask the cabinet questions in plain English.

That is the product. Not “another scanner.” Not a cloud drive. A cabinet that remembers the dates that actually matter.

## Why this can win

Generic scan apps (Adobe Scan, Genius Scan, the Files app) are a commodity. They produce PDFs. They do not tell you the MOT is due in 12 days.

Single-purpose MOT or insurance reminder apps are useful and forgettable. They do not hold the rest of someone’s life admin.

CabinetIQ’s wedge is **UK life admin intelligence, on-device**:

- One capture → structured facts (dates, plates, policy numbers, amounts)
- A home screen that is a command centre, not a file dump
- Reminders before things lapse
- Ask, with citations back to the original document
- Privacy as the brand, not a footnote

Bestsellers in utility are not the ones with the most features. They are the ones that do one expensive job perfectly: *don’t let my life expire.*

## What changed in this pass

The early build had a real engine (Vision OCR, extractors, BM25/RAG, local reminders) wrapped in a prototype shell: five tabs, two labelled “Home,” raw JSON on the document screen, an Ask tab with no prompt, and a search screen that was not on the tab bar.

This revision turns that engine into a product:

- **Home** — greeting, what needs you, Car/Home/Life coverage, recent, one-tap capture
- **Vault** — searchable library with domain and type filters, document cards, swipe/context delete
- **Ask** — suggested questions from what you have actually filed, chat turns, citations
- Human **key facts** instead of dumped JSON, plus edit / delete / export
- First-run onboarding and a **sample MOT** so the loop is visible in 10 seconds
- Brass-on-ink visual system, not generic developer dark mode

## Architecture

- `CabinetIQ/App`: SwiftUI app, Core Data stack, theming, onboarding gate
- `CabinetIQ/Models`: Domain enums, extraction payloads, presentation helpers (`DueStatus`, `FieldCatalog`, `VaultInsights`)
- `CabinetIQ/Services`: Ingestion, classification, extraction, reminders, export, search, RAG, intents
- `CabinetIQ/UI`: Home, Vault, Ask, document detail/editor, capture, settings
- `CabinetIQTests`: Extraction, intents, RAG, and presentation tests

## Build & Run

1. Open `CabinetIQ/CabinetIQ.xcodeproj` in Xcode 15+ (iOS 18 SDK).
2. Select the **CabinetIQ** scheme.
3. Run (`⌘R`). First launch shows onboarding; Home can scan, import, or load a sample MOT.
4. Tests: `⌘U` or `xcodebuild -scheme CabinetIQ -destination 'platform=iOS Simulator,name=iPhone 16' test`.

## The path to a category bestseller

Shipping this UI is the first mile, not the last. The remaining work that actually moves App Store rank:

1. **Accuracy people can trust.** Wrong MOT dates kill the product. Expand issuer templates, show confidence, make edit the default when extraction is thin.
2. **The 30-second first document.** Camera quality, edge detect, “we found your MOT expiry” celebration, notification permission *after* value.
3. **Proactive, not archival.** Home should feel like Apple Health for life admin: coverage gaps (“no car insurance filed”), widgets, lock-screen next due date.
4. **UK-specific depth.** MOT, VED, insurance, mortgage fix end, HMRC, council tax. Own this vocabulary. Then expand.
5. **Share Sheet + Shortcuts** as acquisition. “Save to CabinetIQ” from Mail and Photos is how the vault fills.
6. **App Store narrative.** Screenshots of Home (attention + coverage), a scanned MOT with extracted facts, and Ask answering “when does my MOT expire?” Privacy badge. No cloud account.
7. **Widget + notification copy** that people screenshot. That is marketing.
8. **Do not add accounts, sync, or social** until the on-device loop is beloved. Privacy is the moat.

## Extending extractors

1. Add heuristics in `DocumentClassifier`.
2. Add regex/layout helpers in `RegexExtractors` / `FieldExtractor`.
3. Add a fixture under `Resources/Fixtures` and a test.
4. Add a suggested question in `VaultInsights` when that `DocType` is present.
