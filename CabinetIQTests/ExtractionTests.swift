import XCTest
@testable import CabinetIQ

final class ExtractionTests: XCTestCase {
    @MainActor
    func testMOTExtraction() async throws {
        let text = try fixture(named: "mot_sample")
        let fields = await FieldExtractor.shared.extract(for: .mot, text: text)
        XCTAssertEqual(fields.mot?.vrm, "CAB123")
        XCTAssertNotNil(fields.dueDate)
        XCTAssertFalse(fields.mot?.advisories.isEmpty ?? true)
    }

    @MainActor
    func testInsuranceExtraction() async throws {
        let text = try fixture(named: "insurance_sample")
        let fields = await FieldExtractor.shared.extract(for: .insurance, text: text)
        XCTAssertEqual(fields.policyNumber, "INS-ABC-123")
        XCTAssertNotNil(fields.dueDate)
    }

    @MainActor
    func testUtilityExtraction() async throws {
        let text = try fixture(named: "utility_sample")
        let fields = await FieldExtractor.shared.extract(for: .utility, text: text)
        XCTAssertEqual(fields.utility?.mpan?.replacingOccurrences(of: " ", with: ""), "1234567890123")
        XCTAssertNotNil(fields.amountGBP)
    }

    private func fixture(named name: String) throws -> String {
        let bundle = Bundle(for: Self.self)
        guard let url = bundle.url(forResource: name, withExtension: "txt", subdirectory: "Fixtures") else {
            throw XCTSkip("Missing fixture \(name)")
        }
        return try String(contentsOf: url)
    }
}
