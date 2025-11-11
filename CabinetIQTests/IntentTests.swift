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
}
