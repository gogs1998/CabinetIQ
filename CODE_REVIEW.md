# CabinetIQ - Comprehensive Code Review Report

**Review Date**: 2025-11-11
**Reviewer**: Claude Code
**Branch**: claude/code-review-011CV1eMyKrwXzJ64BUfMjcj

---

## Executive Summary

CabinetIQ is a privacy-first iOS document management application with OCR, classification, field extraction, BM25 search, RAG capabilities, and reminder scheduling. All processing occurs on-device using Core Data for persistence.

**Overall Code Quality Score**: 6.5/10

The codebase demonstrates solid Swift/SwiftUI fundamentals with well-architected separation of concerns. However, it requires critical fixes before production release, particularly around error handling, hardcoded configuration values, and test coverage.

### Files Reviewed
- 38 Swift source files
- 4 configuration files
- ~2,800 lines of code

### Issue Summary
- **Critical Issues**: 4 (Must fix immediately)
- **Major Issues**: 6 (High priority)
- **Moderate Issues**: 9 (Medium priority)
- **Minor Issues**: 11 (Nice to have)

---

## Critical Issues 🔴

### 1. Data Loss Risk - Fatal Error on Core Data Failure
**File**: `CabinetIQ/App/Persistence.swift:15`
```swift
fatalError("Unresolved error: \(error)")
```
**Problem**: Application crashes if Core Data persistent store fails to load, causing complete data loss.

**Impact**: Users lose all stored documents if the Core Data store becomes corrupted or migration fails.

**Recommendation**: Implement graceful degradation:
```swift
container.loadPersistentStores { description, error in
    if let error = error as NSError? {
        // Attempt recovery or create fresh store
        print("Core Data error: \(error), \(error.userInfo)")
        // Option 1: Try to recover
        // Option 2: Create backup and fresh store
        // Option 3: Show user error UI with recovery options
    }
}
```

---

### 2. Hardcoded Development App Group ID
**File**: `Shared/SharedImportQueue.swift:10`
```swift
private static let appGroupID = "group.com.example.CabinetIQ"
```
**Problem**: Development placeholder is hardcoded in source; share extension will not work in production.

**Impact**: Share sheet functionality completely broken; data isolation issues.

**Recommendation**: Move to Info.plist or build configuration:
```swift
private static let appGroupID: String = {
    guard let id = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String else {
        fatalError("Missing AppGroupIdentifier in Info.plist")
    }
    return id
}()
```

---

### 3. Force Unwrap Crash in PDF Processing
**File**: `CabinetIQ/Services/IngestPipeline.swift:26`
```swift
cgImage = page.thumbnail(of: CGSize(width: 1200, height: 1200), for: .mediaBox).cgImage!
```
**Problem**: Force unwrap will crash if PDF thumbnail generation fails (corrupted PDF, unsupported format).

**Impact**: Application crash when processing certain PDFs.

**Recommendation**: Use optional binding:
```swift
guard let cgImage = page.thumbnail(of: CGSize(width: 1200, height: 1200), for: .mediaBox).cgImage else {
    throw NSError(domain: "CabinetIQ", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to generate PDF thumbnail"])
}
```

---

### 4. Silent Export Failure
**File**: `CabinetIQ/UI/DocumentDetailView.swift:104`
```swift
} catch {
    // TODO: surface error to user via alert if needed
}
```
**Problem**: Export failures are silently swallowed with no user feedback.

**Impact**: Users believe export succeeded when it failed; poor UX.

**Recommendation**: Add error state:
```swift
@State private var exportError: Error?

// In catch block:
} catch {
    exportError = error
}

// Add alert:
.alert("Export Failed", isPresented: Binding(get: { exportError != nil }, set: { _ in exportError = nil })) {
    Button("OK", role: .cancel) {}
} message: {
    Text(exportError?.localizedDescription ?? "Unknown error")
}
```

---

## Major Issues 🟠

### 5. Inefficient Search Index Cache Invalidation
**File**: `CabinetIQ/Services/SearchIndex.swift:47`
```swift
idfCache.removeAll()
```
**Problem**: Entire IDF cache cleared on every document addition/removal, forcing full recalculation on next search.

**Impact**: O(n) performance degradation; wasted computation on large document sets.

**Recommendation**: Implement incremental IDF updates:
```swift
func updateIDF(for token: String) {
    let df = vectors.values.filter { $0.terms[token] != nil }.count
    idfCache[token] = log((Double(vectors.count - df + 1) / Double(df + 1)) + 1)
}
```

---

### 6. Race Condition in Success Messages
**File**: `CabinetIQ/UI/InboxView.swift:157-161`
```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
    if successMessage == message {
        successMessage = nil
    }
}
```
**Problem**: Multiple rapid operations can cause messages to overlap or disappear prematurely.

**Impact**: Users miss important success notifications.

**Recommendation**: Use message queue with unique IDs:
```swift
struct ToastMessage: Identifiable {
    let id = UUID()
    let text: String
    let timestamp = Date()
}

@State private var toastQueue: [ToastMessage] = []
```

---

### 7. Inefficient String Operations in Date Parsing
**File**: `CabinetIQ/Services/RegexExtractors.swift:37-46`
```swift
for line in text.components(separatedBy: .newlines) {
    if line.lowercased().contains(keyword.lowercased()) {
```
**Problem**: `lowercased()` called repeatedly, potentially on same keyword multiple times.

**Impact**: CPU waste on large documents with many lines.

**Recommendation**: Lowercase once before loop:
```swift
let lowerKeyword = keyword.lowercased()
for line in text.components(separatedBy: .newlines) {
    let lowerLine = line.lowercased()
    if lowerLine.contains(lowerKeyword) {
```

---

### 8. Linear Search Performance Bottleneck
**File**: `CabinetIQ/Services/SearchIndex.swift:62-68`
```swift
for (id, vector) in vectors {
    guard matchesScope(vector: vector, scope: scope, documentID: id) else { continue }
```
**Problem**: Every search iterates all vectors; O(n) complexity.

**Impact**: Search becomes slow with >1000 documents.

**Recommendation**: Add scope-based indexing:
```swift
private var vectorsByDomain: [Domain: [UUID]] = [:]
private var vectorsByDocType: [DocType: [UUID]] = [:]

// Update on index/remove
func index(document: DocumentEntity) {
    // ... existing code ...
    vectorsByDomain[document.domainValue, default: []].append(identifier)
    vectorsByDocType[document.docTypeValue, default: []].append(identifier)
}
```

---

### 9. Incorrect Amount Regex Pattern
**File**: `CabinetIQ/Services/RegexExtractors.swift:24`
```swift
private static let amountRegex = try! NSRegularExpression(pattern: "£\\s*[0-9]{1,3}(?:,[0-9]{3})*(?:\\.[0-9]{2})?", options: [.caseInsensitive])
```
**Problem**: Requires exactly 2 decimal places; won't match "£10.5", "£100", or "£1,234.5".

**Impact**: Many valid amounts not extracted.

**Recommendation**: Make decimals optional and flexible:
```swift
pattern: "£\\s*[0-9]{1,3}(?:,[0-9]{3})*(?:\\.[0-9]{1,2})?"
```

---

### 10. Missing File Cleanup After Import
**File**: `CabinetIQ/Services/IngestPipeline.swift:82-90`

**Problem**: `persistExisting` copies files but original source files from share extension are never cleaned up.

**Impact**: Storage bloat over time as imports accumulate.

**Recommendation**: Document cleanup responsibility in comments or implement automatic cleanup after successful copy.

---

## Moderate Issues 🟡

### 11. Forced Dark Mode
**File**: `CabinetIQ/App/CabinetIQApp.swift:21`
```swift
.preferredColorScheme(.dark)
```
**Problem**: Ignores system appearance preference.

**Recommendation**: Remove line to respect system setting or make user-configurable.

---

### 12. Hardcoded Magic Numbers

Multiple instances throughout codebase:

- `InboxView.swift:166` - 60-day upcoming renewals window
- `ReminderService.swift:46` - Hardcoded -30/-7 day reminder offsets
- `SearchIndex.swift:110` - Magic number -30 for snippet context
- `SearchIndex.swift:111` - Magic number 120 for snippet end offset
- `FieldExtractor.swift:222` - Assumes 1-year MOT validity

**Recommendation**: Extract to named constants:
```swift
enum Constants {
    static let upcomingRenewalDays = 60
    static let reminderOffsets = [-30, -7]
    static let snippetContextBefore = 30
    static let snippetContextAfter = 120
    static let motValidityYears = 1
}
```

---

### 13. MOT Validation Logic Incomplete
**File**: `CabinetIQ/Services/FieldExtractor.swift:221-228`
```swift
if mot.expiryDate == nil, let expiry = Calendar.current.date(byAdding: .year, value: 1, to: test) {
```
**Problem**: Assumes all MOTs are 1-year validity, but new cars in UK get 3-year first MOT.

**Impact**: Incorrect reminders for new vehicles.

**Recommendation**: Detect vehicle age or make configurable per document.

---

### 14. Weak Document Classification
**File**: `CabinetIQ/Services/DocumentClassifier.swift:4-39`

**Problem**: No fuzzy matching, confidence scores, or multi-keyword requirements. Single keyword hit classifies entire document.

**Impact**: High misclassification rate on ambiguous documents.

**Recommendation**: Implement scoring system:
```swift
func classify(text: String) -> (Domain, DocType, String, confidence: Double) {
    let lower = text.lowercased()
    var scores: [(Domain, DocType, String, Double)] = []

    // Score each classification path
    let motKeywords = ["mot test certificate", "vt20", "dvsa"]
    let motScore = motKeywords.filter { lower.contains($0) }.count / Double(motKeywords.count)
    if motScore > 0.3 {
        scores.append((.car, .mot, "DVSA", motScore))
    }

    // Return highest confidence or .other if below threshold
}
```

---

### 15. Missing Empty String Validation
**File**: `CabinetIQ/Models/DocumentEntity+Extensions.swift:34-36`
```swift
if let newTag = fields.policyNumber ?? fields.reference {
    addTag(newTag)
}
```
**Problem**: Empty strings pass through and become tags.

**Recommendation**: Add check:
```swift
if let newTag = fields.policyNumber ?? fields.reference, !newTag.isEmpty {
```

---

### 16. Insufficient Test Coverage
**Files**: `CabinetIQTests/*.swift`

**Problems**:
- Only 3 of 15+ document types tested (MOT, Insurance, Utility)
- No negative test cases (malformed input, edge cases)
- No boundary testing (very large amounts, dates, invalid dates)
- Intent tests only cover MOT scenario
- RAG tests have single test case
- No tests for classification logic
- No tests for SearchIndex BM25 scoring

**Current Coverage**: ~15%
**Recommended**: ≥70%

**Recommendation**: Add comprehensive test suite covering:
- All document types
- Edge cases (nil, empty, malformed)
- Boundary values
- Error paths
- Performance tests for large datasets

---

### 17. Potential Integer Overflow
**File**: `CabinetIQ/Services/FieldExtractor.swift:42, 167-168`
```swift
mot.odometerMiles = Int(digits)
payload.mileage = Int(digits)
```
**Problem**: Silently fails if number exceeds Int.max (unlikely but possible with corrupted OCR).

**Recommendation**: Handle conversion failure:
```swift
if let mileageInt = Int(digits), mileageInt >= 0 {
    payload.mileage = mileageInt
}
```

---

### 18. VRM Regex Too Restrictive
**File**: `CabinetIQ/Services/RegexExtractors.swift:25`
```swift
private static let vrmRegex = try! NSRegularExpression(pattern: "(?i)\\b([A-Z]{2}[0-9]{2} ?[A-Z]{3}|[A-Z]{3} ?[0-9]{3})\\b")
```
**Problem**: Only matches current format (2001+) and one older format; misses many valid historical UK registration plates.

**Impact**: Older vehicles won't have VRM extracted.

**Recommendation**: Expand pattern or document limitation.

---

### 19. Missing Date Validation
**File**: `CabinetIQ/Services/RegexExtractors.swift:27-35`

**Problem**: Parsed dates not validated (e.g., 32/13/2025 would be rejected by DateFormatter but not explicitly checked).

**Recommendation**: Add sanity checks:
```swift
static func parseDate(_ text: String) -> Date? {
    // ... existing parsing ...

    // Validate parsed date is reasonable
    if let date = parsedDate {
        let now = Date()
        let futureLimit = Calendar.current.date(byAdding: .year, value: 50, to: now)!
        let pastLimit = Calendar.current.date(byAdding: .year, value: -50, to: now)!

        guard date >= pastLimit && date <= futureLimit else {
            return nil
        }
        return date
    }
    return nil
}
```

---

## Minor Issues 🟢

### 20. Code Duplication - Currency Formatters

**Files**:
- `CabinetIQ/UI/DocumentRow.swift:33-38`
- `CabinetIQ/UI/DocumentDetailView.swift:113-118`

Both implement identical currency formatters.

**Recommendation**: Extract to shared extension:
```swift
extension NumberFormatter {
    static let gbpCurrency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_GB")
        return formatter
    }()
}
```

---

### 21. Duplicated Fetch Logic

**Files**:
- `CabinetIQ/UI/SearchView.swift:42-47`
- `CabinetIQ/UI/AskView.swift:160-165`

Both implement `fetchDocument(id:)` identically.

**Recommendation**: Add to DocumentEntity extension:
```swift
extension DocumentEntity {
    static func fetch(id: UUID, context: NSManagedObjectContext) -> DocumentEntity? {
        let request: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequestAll()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
}
```

---

### 22. Inconsistent Error Handling

**Throughout Services Layer**

Some functions throw errors, some return optionals, some silently fail.

**Recommendation**: Define custom error types:
```swift
enum CabinetIQError: LocalizedError {
    case ocrFailed(reason: String)
    case classificationFailed
    case extractionFailed(docType: DocType)
    case exportFailed(reason: String)
    case unsupportedFileType(String)

    var errorDescription: String? {
        // ... descriptions
    }
}
```

---

### 23. Missing API Documentation

**All Files**

No DocC comments on public types, methods, or complex algorithms.

**Recommendation**: Add documentation:
```swift
/// Performs Okapi BM25 scoring for document ranking
///
/// - Parameters:
///   - tokens: Query tokens to score against
///   - vector: Document vector containing term frequencies
///   - k1: Term frequency saturation parameter (default: 1.5)
///   - b: Document length normalization (default: 0.75)
/// - Returns: BM25 relevance score
private func bm25(tokens: [String], vector: Vector, k1: Double = 1.5, b: Double = 0.75) -> Double
```

---

### 24. Accessibility Issues

**DocumentRow.swift:19**
```swift
.labelStyle(.iconOnly)
```
Icon-only labels may confuse VoiceOver users.

**AskView.swift:79-80**
```swift
Text(message.source == .rag ? "RAG" : "Intent")
```
Technical terminology exposed to users.

**Recommendation**:
- Add accessibility labels
- Use user-friendly terminology
- Add `.accessibilityLabel()` modifiers

---

### 25. Performance - String Filter Operation
**File**: `CabinetIQ/Services/FieldExtractor.swift:232`
```swift
func onlyDigits() -> String { filter { $0.isNumber } }
```
**Problem**: Creates new string on every character check.

**Recommendation**: Use optimized approach for large strings:
```swift
func onlyDigits() -> String {
    String(self.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) })
}
```

---

### 26. Unused ObservableObject Conformance
**File**: `CabinetIQ/Services/ExportService.swift:3`
```swift
final class ExportService: ObservableObject {
```
**Problem**: No `@Published` properties; conformance unused.

**Recommendation**: Remove `ObservableObject` conformance.

---

### 27. Unused Enum Case
**File**: `CabinetIQ/Models/Domain.swift:56`
```swift
case document(UUID)
```
**Problem**: `AskScope.document(_)` defined but never used in UI.

**Recommendation**: Implement feature or remove case.

---

### 28. Locale Hardcoding

**Multiple Files**: RegexExtractors.swift, DocumentRow.swift, DocumentDetailView.swift

All hardcode `"en_GB"` locale.

**Recommendation**: Use `Locale.current` or make configurable:
```swift
static let userLocale = Locale.current
static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = userLocale
    formatter.dateFormat = "dd/MM/yyyy"
    return formatter
}()
```

---

### 29. Outdated SwiftUI API Usage
**File**: `CabinetIQ/UI/InboxView.swift:7`
```swift
@FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \DocumentEntity.createdAt, ascending: false)])
```
**Problem**: Using Objective-C `NSSortDescriptor` instead of Swift-native API.

**Recommendation**: Use `SortDescriptor` for iOS 15+:
```swift
@FetchRequest(sortDescriptors: [SortDescriptor(\.createdAt, order: .reverse)])
```

---

### 30. Global Extension Collision Risk
**File**: `CabinetIQ/UI/AskView.swift:175-177`
```swift
extension UUID: Identifiable {
    public var id: UUID { self }
}
```
**Problem**: Global extension on Foundation type may conflict with other code.

**Recommendation**: Use `.id(\.self)` inline or wrapper type.

---

### 31. Missing Privacy Manifest
**Issue**: No `PrivacyInfo.xcprivacy` file despite using privacy-sensitive APIs.

**APIs Used**:
- Camera (VisionKit)
- Photo Library (PhotosUI)
- User Notifications
- File System Access

**Impact**: App Store rejection on future submissions (required iOS 17+).

**Recommendation**: Create PrivacyInfo.xcprivacy with required privacy declarations.

---

## Architectural Analysis

### Strengths ✅

1. **Clean Separation of Concerns**
   - Well-defined App/Models/Services/UI layers
   - Services are cohesive and focused

2. **Testability**
   - Dependency injection used (FieldExtractor, RAGEngine accept protocol parameters)
   - Core Data uses PersistenceController.preview for testing

3. **Privacy-First Design**
   - Zero networking
   - All processing on-device
   - No third-party SDKs

4. **Modern Swift Practices**
   - async/await used consistently
   - Structured concurrency (Task, AsyncSequence)
   - Value types for models

5. **Core Data Best Practices**
   - Merge policy configured correctly
   - Automatic change merging enabled
   - View context properly passed via environment

### Weaknesses ⚠️

1. **No Error Recovery Strategy**
   - Most errors either crash (fatalError) or fail silently
   - No graceful degradation for critical failures

2. **Limited Scalability**
   - Linear search algorithms won't scale beyond ~1000 documents
   - Full cache invalidation on every change
   - No pagination or lazy loading

3. **Tight Coupling via Singletons**
   - Heavy use of `.shared` singletons makes testing harder
   - Difficult to mock dependencies
   - Global state management issues

4. **No Observability**
   - No crash reporting
   - No analytics or feature usage tracking
   - No performance monitoring

5. **Missing Migration Strategy**
   - No Core Data migration plan for schema changes
   - Will crash if model changes without migration

---

## Security Audit

### Secure Practices ✅
- No networking reduces attack surface
- Sandbox-appropriate file operations
- User data stays local (privacy-preserving)
- Proper entitlements usage

### Concerns ⚠️

1. **File Path Injection Risk**
   - `CabinetIQ/Services/IngestPipeline.swift:92-98`: File paths stored as strings could theoretically be manipulated
   - Mitigation: Validate all file paths before use

2. **Share Extension Input Validation**
   - `CabinetIQShareExtension/ShareViewController.swift:55-64`: Accepts arbitrary file types without size limits
   - Potential DoS via memory exhaustion
   - Recommendation: Add file size limits and type validation

3. **Entitlements Review Needed**
   - Unable to verify app group entitlements match bundle IDs
   - Unable to verify file access scope appropriately restricted

---

## Performance Recommendations

### High Impact 🔴

1. **Implement Core Spotlight Integration**
   - Replace custom BM25 with native iOS search
   - Benefits: Faster, system-integrated, better battery life
   ```swift
   import CoreSpotlight
   import MobileCoreServices

   func indexDocument(_ document: DocumentEntity) {
       let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
       attributeSet.title = document.issuer
       attributeSet.contentDescription = document.ocrText
       // ... set other attributes

       let item = CSSearchableItem(uniqueIdentifier: document.id!.uuidString,
                                   domainIdentifier: "com.example.CabinetIQ",
                                   attributeSet: attributeSet)
       CSSearchableIndex.default().indexSearchableItems([item])
   }
   ```

2. **Add Pagination/Lazy Loading**
   - InboxView loads all documents at once
   - Implement batch loading for large datasets
   - Use `@FetchRequest` with `fetchLimit` and offset

3. **Background OCR Processing**
   - OCR blocks UI thread
   - Move to background queue:
   ```swift
   Task.detached(priority: .userInitiated) {
       let (text, lines) = try await performOCR(on: images)
       await MainActor.run {
           // Update UI
       }
   }
   ```

4. **Optimize Image Resolution**
   - 1200x1200 thumbnail may be excessive
   - Test OCR accuracy at lower resolutions
   - Potential 4x memory savings

### Medium Impact 🟡

1. **Cache Compiled Regexes**
   - Many regex patterns created on demand
   - Cache all in RegexExtractors initialization

2. **Throttle SearchIndex Persistence**
   - Currently writes on every document change
   - Batch writes or delay until app backgrounds

3. **Add LRU Cache for Documents**
   - Frequently accessed documents fetched repeatedly
   - Implement NSCache for recent documents

---

## Recommendations by Priority

### P0 - Critical (Immediate) 🔴

1. ✅ Fix Core Data fatal error crash
2. ✅ Replace hardcoded app group ID
3. ✅ Fix force unwrap in PDF processing
4. ✅ Add export error handling to UI

### P1 - High (This Sprint) 🟠

5. ⚠️ Implement incremental IDF cache updates
6. ⚠️ Fix success message race condition
7. ⚠️ Fix amount regex to handle decimals correctly
8. ⚠️ Expand test coverage to ≥70%
9. ⚠️ Add proper error types throughout

### P2 - Medium (Next Quarter) 🟡

10. 📝 Extract hardcoded constants to configuration
11. 📝 Implement robust MOT validation logic
12. 📝 Add confidence scoring to classification
13. 📝 Internationalization support
14. 📝 Add privacy manifest file
15. 📝 Implement Core Spotlight integration

### P3 - Nice to Have (Backlog) 🟢

16. 💡 Refactor currency formatters to shared utility
17. 💡 Add comprehensive doc comments
18. 💡 Add analytics framework
19. 💡 Implement Core Data migration strategy
20. 💡 Add accessibility improvements

---

## Testing Recommendations

### Unit Tests Needed
- [ ] All RegexExtractors patterns
- [ ] DocumentClassifier with edge cases
- [ ] FieldExtractor for all 15 document types
- [ ] SearchIndex BM25 scoring accuracy
- [ ] RAGEngine with various corpus sizes
- [ ] Date parsing edge cases (invalid dates, future dates)
- [ ] Amount extraction edge cases

### Integration Tests Needed
- [ ] End-to-end ingestion pipeline
- [ ] Share extension → main app flow
- [ ] Intent shortcuts execution
- [ ] Core Data migrations

### UI Tests Needed
- [ ] Scanner flow
- [ ] Photo picker import
- [ ] File import
- [ ] Document detail export
- [ ] Ask view question flow

---

## Conclusion

**Summary**: CabinetIQ is a well-architected iOS application with solid foundations. The privacy-first, on-device approach is commendable and the code demonstrates good Swift/SwiftUI practices. However, several critical issues must be addressed before production release:

1. Error handling needs significant improvement
2. Hardcoded configuration values must be externalized
3. Test coverage is insufficient
4. Performance optimizations needed for scalability

**Recommendation**: Address all P0 and P1 issues before production release. The codebase will benefit from incremental improvements in P2 and P3 categories over subsequent releases.

**Estimated Effort**:
- P0 fixes: 2-3 days
- P1 improvements: 1-2 weeks
- P2 enhancements: 1 month
- P3 refinements: Ongoing

**Final Grade**: 6.5/10 - Good foundation requiring production hardening

---

*End of Code Review Report*
