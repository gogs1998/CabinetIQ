# CabinetIQ

CabinetIQ is a private life-admin vault for iPhone. Scan an MOT, insurance policy, mortgage letter, or bill. Vision OCR reads every line on this device. Then you can ask the cabinet questions in plain English — plate, policy number, rate, amount — and get an answer with a citation back to the original.

Reminders are what fall out of that: if the text contains a due date, we nudge you before it lapses.

That is the product. Not “another scanner.” A cabinet you can query.

## Why this can win

Generic scan apps (Adobe Scan, Genius Scan, the Files app) are a commodity. They produce PDFs. They do not answer “what’s my registration?”

Single-purpose MOT or insurance reminder apps are useful and forgettable. They do not hold the rest of someone’s life admin.

CabinetIQ’s wedge is **on-device OCR you can query**:

- One capture → full text + structured facts (dates, plates, policy numbers, amounts)
- Ask in English, with citations back to the original page
- A home screen that starts with “Ask anything you scanned”
- Reminders before dates in that text lapse
- Privacy as the brand, not a footnote

Scanners produce PDFs. Search boxes filter filenames. CabinetIQ answers “what’s my registration?” from the words it read.

## What changed in this pass

The early build had a real engine (Vision OCR, extractors, BM25/RAG, local reminders) wrapped in a prototype shell: five tabs, two labelled “Home,” raw JSON on the document screen, an Ask tab with no prompt, and a search screen that was not on the tab bar.

This revision turns that engine into a product:

- **Home** — “Ask anything you scanned” is the hero, plus coverage and renewals
- **Vault** — searchable library with domain and type filters, document cards, swipe/context delete
- **Ask** — questions from OCR facts (plate, policy, amount), citations from the text we read
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
6. **App Store narrative.** Screenshots of a scan being read, Home’s “Ask anything you scanned” bar, and Ask answering “what’s my registration?” from the MOT text. Privacy badge. No cloud account.
7. **Widget + notification copy** that people screenshot. That is marketing.
8. **Do not add accounts, sync, or social** until the on-device loop is beloved. Privacy is the moat.

## Extending extractors

1. Add heuristics in `DocumentClassifier`.
2. Add regex/layout helpers in `RegexExtractors` / `FieldExtractor`.
3. Add a fixture under `Resources/Fixtures` and a test.
4. Add a suggested question in `VaultInsights` when that `DocType` is present.
