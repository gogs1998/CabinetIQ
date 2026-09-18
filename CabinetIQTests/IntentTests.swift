import XCTest
import CoreData
@testable import CabinetIQ

final class IntentTests: XCTestCase {
    @MainActor
    func testMotDueIntent() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let doc = DocumentEntity(context: context)
        doc.id = UUID()
        doc.createdAt = Date()
        doc.source = DocumentSource.scan.rawValue
        doc.domain = Domain.car.rawValue
        doc.docType = DocType.mot.rawValue
        doc.dueDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())
        doc.issuer = "DVSA"
        doc.ocrText = "MOT test certificate CAB888"
        try context.save()

        let answer = IntentShortcuts.answer(query: "When's my MOT due for CAB888?", context: context)
        XCTAssertNotNil(answer)
        XCTAssertEqual(answer?.citations.first?.documentID, doc.id)
    }

    @MainActor
    func testRegistrationQueryReadsExtractedOCRFields() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let doc = DocumentEntity(context: context)
        doc.id = UUID()
        doc.createdAt = Date()
        doc.source = DocumentSource.scan.rawValue
        doc.domain = Domain.car.rawValue
        doc.docType = DocType.mot.rawValue
        doc.issuer = "DVSA"
        doc.ocrText = "MOT Test Certificate Vehicle: CAB888"
        var fields = ExtractedFields()
        var mot = MOTFields()
        mot.vrm = "CAB888"
        fields.mot = mot
        doc.apply(fields: fields)
        try context.save()

        let answer = IntentShortcuts.answer(query: "What's my registration?", context: context)
        XCTAssertTrue(answer?.text.contains("CAB888") == true)
        XCTAssertEqual(answer?.citations.first?.documentID, doc.id)
    }

    @MainActor
    func testPolicyNumberQuery() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let doc = DocumentEntity(context: context)
        doc.id = UUID()
        doc.createdAt = Date()
        doc.source = DocumentSource.scan.rawValue
        doc.domain = Domain.car.rawValue
        doc.docType = DocType.insurance.rawValue
        doc.issuer = "Admiral"
        doc.ocrText = "Certificate of Insurance Policy Number: INS-ABC-123"
        var fields = ExtractedFields()
        fields.policyNumber = "INS-ABC-123"
        var insurance = InsuranceFields()
        insurance.policyNumber = "INS-ABC-123"
        fields.insurance = insurance
        doc.apply(fields: fields)
        try context.save()

        let answer = IntentShortcuts.answer(query: "What's my policy number?", context: context)
        XCTAssertTrue(answer?.text.contains("INS-ABC-123") == true)
    }
}
