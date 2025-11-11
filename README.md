# CabinetIQ

CabinetIQ is a SwiftUI + Core Data vault for life admin that runs 100% on-device. It ingests scans/photos/files/share-sheet inputs, OCRs content with Vision, classifies documents into Home/Car/Life domains, extracts structured fields via deterministic regex/layout rules, schedules local reminders, and answers questions through deterministic intents or a local BM25+RAG engine ready for future On-Device FMs.

## Features
- **Capture**: VisionKit scanner, multi-photo picker, Files importer, and share-entry stub.
- **OCR + Extraction**: Vision text recognition with line geometry → domain/type classification → modular extractors for MOT, insurance, mortgage, utilities, HMRC tax, bank statements, warranties, receipts, service reports, and generic fallbacks.
- **Storage**: Core Data `Document` entity keeps OCR text, structured JSON, related geometry, reminder metadata, and local search cache.
- **Search & Ask**: In-memory BM25-ish scorer powers fast vault search plus the Ask tab; when deterministic intents don’t answer, a local RAG engine chunks OCR text, retrieves snippets, and (optionally) forwards them to a pluggable OnDeviceFM interface while always returning citations.
- **Reminders & Export**: −30/−7-day local notifications for due dates and per-document “Export JSON + Original” bundles.
- **Privacy-first**: No networking; Settings hosts a disabled “Private Cloud Compute” toggle stub for upcoming on-device FM support.

## Architecture
- `CabinetIQ/App`: SwiftUI app, Core Data stack, theming.
- `CabinetIQ/Models`: Domain enums, Codable extraction payloads, and the Core Data model.
- `CabinetIQ/Services`: Pipelines for ingestion, classification, extraction, reminders, export, search, RAG, on-device FM stubs, and deterministic intents.
- `CabinetIQ/UI`: SwiftUI views (Inbox, domains, detail, search, Ask chat, scanner sheets, settings).
- `CabinetIQ/Resources`: Asset catalog and deterministic text fixtures backing tests.
- `CabinetIQTests`: Unit tests for extraction, intents, and RAG retrieval.

## Build & Run
1. Open `CabinetIQ/CabinetIQ.xcodeproj` in Xcode 15+ (iOS 18 SDK, Swift 5.10).
2. Select the **CabinetIQ** scheme + target simulator or device.
3. Run (`⌘R`). Use the Inbox “+” menu to scan/import documents; reminders require notification permission.
4. Run tests with `⌘U` or `xcodebuild -scheme CabinetIQ -destination 'platform=iOS Simulator,name=iPhone 15' test`.

## Extending extractors & issuer templates
1. Add heuristics/tokens in `DocumentClassifier` for the new doc type + map to `DocType`.
2. Create regex/layout helpers inside `RegexExtractors` and implement a new branch in `FieldExtractor`.
3. Drop representative fixtures under `Resources/Fixtures` and extend the relevant XCTest files.
4. (Future) register issuer templates via YAML by loading them inside `FieldExtractor` before the regex phase.

## Future work
- Share extension target + Shortcuts intents.
- Richer document previews (PDFKit page viewer) and markup.
- SQLite FTS5 / Core Spotlight bridge for larger vaults.
- Wire up Apple’s On-Device Foundation Models via Private Cloud Compute when publicly available.
