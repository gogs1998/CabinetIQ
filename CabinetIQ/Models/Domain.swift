import Foundation

enum Domain: String, CaseIterable, Identifiable, Codable {
    case car = "Car"
    case home = "Home"
    case life = "Life"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .car: return "car.fill"
        case .home: return "house.fill"
        case .life: return "heart.text.square"
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

    var suggestedDomain: Domain {
        switch self {
        case .mot, .serviceRepair: return .car
        case .mortgage, .utility, .tenancy: return .home
        default: return .life
        }
    }
}

enum DocumentSource: String, Codable, CaseIterable {
    case scan, photos, files, share
}

enum AskScope: Hashable {
    case all
    case domain(Domain)
    case docType(DocType)
    case document(UUID)
}
