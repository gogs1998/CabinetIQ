import XCTest
import CoreData
@testable import CabinetIQ

final class PresentationTests: XCTestCase {
    func testDueStatusWindows() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1))!

        XCTAssertEqual(DueStatus.from(dueDate: nil, now: now, calendar: calendar), .none)
        XCTAssertEqual(
            DueStatus.from(dueDate: calendar.date(byAdding: .day, value: -3, to: now), now: now, calendar: calendar),
            .overdue(days: 3)
        )
        XCTAssertEqual(
            DueStatus.from(dueDate: now, now: now, calendar: calendar),
            .dueSoon(days: 0)
        )
        XCTAssertEqual(
            DueStatus.from(dueDate: calendar.date(byAdding: .day, value: 12, to: now), now: now, calendar: calendar),
            .dueSoon(days: 12)
        )
        XCTAssertEqual(
            DueStatus.from(dueDate: calendar.date(byAdding: .day, value: 60, to: now), now: now, calendar: calendar),
            .upcoming(days: 60)
        )
        XCTAssertEqual(
            DueStatus.from(dueDate: calendar.date(byAdding: .day, value: 200, to: now), now: now, calendar: calendar),
            .clear
        )
    }

    func testFieldCatalogHidesEmptyValues() {
        var fields = ExtractedFields()
        fields.mot = MOTFields(vrm: "CAB123", odometerMiles: 45678, advisories: ["Nearside tyre"])
        fields.dueDate = Date(timeIntervalSince1970: 1_741_852_800)
        let rows = FieldCatalog.rows(from: fields)
        XCTAssertTrue(rows.contains(where: { $0.label == "Registration" && $0.value == "CAB123" }))
        XCTAssertTrue(rows.contains(where: { $0.label == "Odometer" && $0.value.contains("45") }))
        XCTAssertFalse(rows.contains(where: { $0.label == "Account" }))
        XCTAssertFalse(rows.contains { $0.value.isEmpty })
    }

    func testSuggestedQuestionsFollowVaultContents() {
        let empty = VaultInsights.suggestedQuestions(types: [], isEmpty: true)
        XCTAssertEqual(empty.first, "When does my MOT expire?")

        let filled = VaultInsights.suggestedQuestions(types: [.mortgage, .taxHMRC], isEmpty: false)
        XCTAssertTrue(filled.contains("What is my mortgage rate?"))
        XCTAssertTrue(filled.contains("When is my tax deadline?"))
        XCTAssertTrue(filled.contains("What needs my attention?"))
        XCTAssertFalse(filled.contains("When does my MOT expire?"))

        let fromFacts = VaultInsights.suggestedQuestions(
            types: [.mot],
            facts: [.registration, .policyNumber],
            isEmpty: false
        )
        XCTAssertTrue(fromFacts.contains("What’s the registration on my MOT?"))
        XCTAssertTrue(fromFacts.contains("What’s my policy number?"))
    }

    @MainActor
    func testCoverageAndAttentionUseDueDates() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let calendar = Calendar.current
        let now = Date()

        let overdue = DocumentEntity(context: context)
        overdue.id = UUID()
        overdue.createdAt = now
        overdue.domain = Domain.car.rawValue
        overdue.docType = DocType.mot.rawValue
        overdue.issuer = "DVSA"
        overdue.dueDate = calendar.date(byAdding: .day, value: -2, to: now)
        overdue.source = DocumentSource.scan.rawValue

        let later = DocumentEntity(context: context)
        later.id = UUID()
        later.createdAt = now
        later.domain = Domain.home.rawValue
        later.docType = DocType.utility.rawValue
        later.issuer = "Octopus"
        later.dueDate = calendar.date(byAdding: .day, value: 20, to: now)
        later.source = DocumentSource.scan.rawValue
        try context.save()

        let attention = VaultInsights.attentionItems(in: [overdue, later], now: now)
        XCTAssertEqual(attention.first?.issuer, "DVSA")

        let car = VaultInsights.coverage(for: .car, in: [overdue, later], now: now)
        XCTAssertEqual(car.count, 1)
        XCTAssertTrue(car.status.needsAttention)

        let life = VaultInsights.coverage(for: .life, in: [overdue, later], now: now)
        XCTAssertEqual(life.count, 0)
        XCTAssertEqual(life.headline, "Nothing filed yet")
    }

    @MainActor
    func testBundledSampleExtractsMOT() async {
        let classified = DocumentClassifier().classify(text: BundledSamples.mot)
        XCTAssertEqual(classified.1, .mot)
        let fields = await FieldExtractor.shared.extract(for: .mot, text: BundledSamples.mot)
        XCTAssertEqual(fields.mot?.vrm, "CAB123")
        XCTAssertNotNil(fields.dueDate)
    }

    func testGreetingBuckets() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let morning = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 8))!
        let afternoon = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 14))!
        let evening = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 20))!
        XCTAssertEqual(VaultInsights.greeting(at: morning, calendar: calendar), "Good morning")
        XCTAssertEqual(VaultInsights.greeting(at: afternoon, calendar: calendar), "Good afternoon")
        XCTAssertEqual(VaultInsights.greeting(at: evening, calendar: calendar), "Good evening")
    }

    func testVehicleInsuranceClassifiesToCar() {
        let classified = DocumentClassifier().classify(text: """
        Certificate of Insurance
        Policy Number: INS-ABC-123
        Vehicle VRM CAB123
        Premium £456.70
        """)
        XCTAssertEqual(classified.0, .car)
        XCTAssertEqual(classified.1, .insurance)
    }

    @MainActor
    func testAttentionIntentListsUpcomingDocuments() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let doc = DocumentEntity(context: context)
        doc.id = UUID()
        doc.createdAt = Date()
        doc.source = DocumentSource.scan.rawValue
        doc.domain = Domain.car.rawValue
        doc.docType = DocType.mot.rawValue
        doc.issuer = "DVSA"
        doc.dueDate = Calendar.current.date(byAdding: .day, value: 8, to: Date())
        doc.ocrText = "MOT test certificate"
        try context.save()

        let answer = IntentShortcuts.answer(query: "What needs my attention?", context: context)
        XCTAssertNotNil(answer)
        XCTAssertTrue(answer?.text.contains("DVSA") == true)
    }
}
