import Foundation
import CoreGraphics

struct ExtractedFields: Codable, Equatable {
    var issueDate: Date?
    var dueDate: Date?
    var amountGBP: Decimal?
    var reference: String?
    var accountNumber: String?
    var policyNumber: String?
    var counterparty: String?
    var address: String?

    var mot: MOTFields?
    var insurance: InsuranceFields?
    var mortgage: MortgageFields?
    var utility: UtilityFields?
    var tax: TaxFields?
    var bank: BankStatementFields?
    var warranty: WarrantyFields?
    var receipt: ReceiptFields?
    var service: ServiceRepairFields?

    init() {}
}

struct MOTFields: Codable, Equatable {
    var vrm: String?
    var testDate: Date?
    var expiryDate: Date?
    var odometerMiles: Int?
    var advisories: [String] = []
    var defects: [String] = []
    var tyreNotes: [String] = []
}

struct InsuranceFields: Codable, Equatable {
    var policyStart: Date?
    var policyEnd: Date?
    var premium: Decimal?
    var policyNumber: String?
    var subject: String?
}

struct MortgageFields: Codable, Equatable {
    var lender: String?
    var productName: String?
    var rate: Double?
    var fixEnd: Date?
    var monthlyPayment: Decimal?
    var balance: Decimal?
}

struct UtilityFields: Codable, Equatable {
    var supplyType: String?
    var tariff: String?
    var unitRate: Decimal?
    var standingCharge: Decimal?
    var mpan: String?
    var mprn: String?
    var accountNo: String?
}

struct TaxFields: Codable, Equatable {
    var taxYear: String?
    var amountDue: Decimal?
    var paymentRef: String?
    var deadline: Date?
}

struct BankStatementFields: Codable, Equatable {
    var sortCode: String?
    var accountNumber: String?
    var periodStart: Date?
    var periodEnd: Date?
    var closingBalance: Decimal?
}

struct WarrantyFields: Codable, Equatable {
    var product: String?
    var serial: String?
    var warrantyStart: Date?
    var warrantyEnd: Date?
}

struct ReceiptFields: Codable, Equatable {
    var merchant: String?
    var vat: Decimal?
    var total: Decimal?
    var paymentMethod: String?
}

struct ServiceRepairFields: Codable, Equatable {
    var vehicleVRM: String?
    var mileage: Int?
    var items: [String] = []
    var advisories: [String] = []
}

struct Citation: Identifiable, Codable {
    var id: UUID
    var documentID: UUID
    var snippet: String
    var startOffset: Int
}

enum AskAnswerSource {
    case deterministic
    case rag
}

struct AskAnswer: Identifiable {
    let id = UUID()
    let question: String
    let text: String
    let citations: [Citation]
    let source: AskAnswerSource
}

struct LineGeometry: Codable, Equatable {
    let text: String
    let boundingBox: CGRect

    init(text: String, boundingBox: CGRect) {
        self.text = text
        self.boundingBox = boundingBox
    }

    enum CodingKeys: String, CodingKey { case text, x, y, width, height }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        let x = try container.decode(CGFloat.self, forKey: .x)
        let y = try container.decode(CGFloat.self, forKey: .y)
        let width = try container.decode(CGFloat.self, forKey: .width)
        let height = try container.decode(CGFloat.self, forKey: .height)
        boundingBox = CGRect(x: x, y: y, width: width, height: height)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(text, forKey: .text)
        try container.encode(boundingBox.origin.x, forKey: .x)
        try container.encode(boundingBox.origin.y, forKey: .y)
        try container.encode(boundingBox.size.width, forKey: .width)
        try container.encode(boundingBox.size.height, forKey: .height)
    }
}
