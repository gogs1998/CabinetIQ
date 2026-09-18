import Foundation

enum Domain: String, CaseIterable, Identifiable, Codable {
    case car = "Car"
    case home = "Home"
    case life = "Life"

    var id: String { rawValue }
    var displayName: String { rawValue }

    var icon: String {
        switch self {
        case .car: return "car.fill"
        case .home: return "house.fill"
        case .life: return "heart.text.square.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .car: return "MOT, insurance, service"
        case .home: return "Mortgage, bills, tenancy"
        case .life: return "Tax, bank, warranties"
        }
    }
}

enum DocType: String, CaseIterable, Identifiable, Codable {
    case mot = "MOT"
    case insurance = "Insurance"
    case mortgage = "Mortgage"
    case utility = "Utility"
    case taxHMRC = "TaxHMRC"
    case warranty = "Warranty"
    case receipt = "Receipt"
    case invoice = "Invoice"
    case bankStatement = "BankStatement"
    case serviceRepair = "ServiceRepair"
    case tenancy = "Tenancy"
    case education = "Education"
    case medical = "Medical"
    case travel = "Travel"
    case government = "Government"
    case other = "Other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mot: return "MOT"
        case .insurance: return "Insurance"
        case .mortgage: return "Mortgage"
        case .utility: return "Utility bill"
        case .taxHMRC: return "HMRC tax"
        case .warranty: return "Warranty"
        case .receipt: return "Receipt"
        case .invoice: return "Invoice"
        case .bankStatement: return "Bank statement"
        case .serviceRepair: return "Service"
        case .tenancy: return "Tenancy"
        case .education: return "Education"
        case .medical: return "Medical"
        case .travel: return "Travel"
        case .government: return "Government"
        case .other: return "Document"
        }
    }

    var icon: String {
        switch self {
        case .mot: return "checkmark.seal.fill"
        case .insurance: return "shield.fill"
        case .mortgage: return "building.columns.fill"
        case .utility: return "bolt.fill"
        case .taxHMRC: return "sterlingsign.circle.fill"
        case .warranty: return "wrench.and.screwdriver.fill"
        case .receipt, .invoice: return "doc.text.fill"
        case .bankStatement: return "creditcard.fill"
        case .serviceRepair: return "screwdriver.fill"
        case .tenancy: return "key.fill"
        case .education: return "graduationcap.fill"
        case .medical: return "cross.case.fill"
        case .travel: return "airplane"
        case .government: return "building.fill"
        case .other: return "doc.fill"
        }
    }

    var suggestedDomain: Domain {
        switch self {
        case .mot, .serviceRepair: return .car
        case .mortgage, .utility, .tenancy: return .home
        default: return .life
        }
    }
}

enum DocumentSource: String, Codable, CaseIterable {
    case scan, photos, files, share, sample

    var displayName: String {
        switch self {
        case .scan: return "Scan"
        case .photos: return "Photos"
        case .files: return "Files"
        case .share: return "Share Sheet"
        case .sample: return "Sample"
        }
    }
}

enum AskScope: Hashable {
    case all
    case domain(Domain)
    case docType(DocType)
    case document(UUID)

    var label: String {
        switch self {
        case .all: return "All documents"
        case .domain(let domain): return domain.displayName
        case .docType(let type): return type.displayName
        case .document: return "This document"
        }
    }
}
