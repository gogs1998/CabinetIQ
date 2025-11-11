import XCTest
import CoreData
@testable import CabinetIQ

final class RAGTests: XCTestCase {
    @MainActor
    func testRagReturnsCitation() async throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let doc = DocumentEntity(context: context)
        doc.id = UUID()
        doc.createdAt = Date()
        doc.source = DocumentSource.scan.rawValue
        doc.domain = Domain.life.rawValue
        doc.docType = DocType.taxHMRC.rawValue
        doc.ocrText = "HM Revenue & Customs payment reference ABC123 due 31/01/2025 amount £1200"
        doc.dueDate = Date()
        doc.jsonFields = try JSONEncoder().encode(ExtractedFields())
        try context.save()
        SearchIndex.shared.index(document: doc)

        let answer = await RAGEngine.shared.answer(question: "When is my HMRC payment due?", scope: .all, context: context)
        XCTAssertFalse(answer.citations.isEmpty)
        XCTAssertEqual(answer.citations.first?.documentID, doc.id)
    }
}
