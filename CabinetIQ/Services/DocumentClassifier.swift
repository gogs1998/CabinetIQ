import Foundation

struct DocumentClassifier {
    func classify(text: String) -> (Domain, DocType, String) {
        let lower = text.lowercased()
        func contains(_ tokens: [String]) -> Bool { tokens.contains(where: lower.contains) }

        if contains(["mot test certificate", "vt20", "dvsa"]) {
            return (.car, .mot, "DVSA")
        } else if contains(["policy number", "premium", "certificate of insurance"]) {
            let vehicle = contains(["vehicle", "motor", "car insurance", "vrm"]) || RegexExtractors.extractVRM(in: text) != nil
            return (vehicle ? .car : .life, .insurance, "Insurance Provider")
        } else if contains(["mortgage", "fixed rate", "lender"]) {
            return (.home, .mortgage, "Mortgage Lender")
        } else if contains(["mpan", "mprn", "standing charge", "unit rate"]) {
            return (.home, .utility, "Utility Provider")
        } else if contains(["hm revenue", "self assessment", "payment reference"]) {
            return (.life, .taxHMRC, "HMRC")
        } else if contains(["account number", "sort code", "statement period"]) {
            return (.life, .bankStatement, "Bank")
        } else if contains(["warranty", "serial number", "warranty period"]) {
            return (.life, .warranty, "Manufacturer")
        } else if contains(["invoice", "vat", "receipt", "subtotal", "total due"]) {
            let type: DocType = lower.contains("invoice") ? .invoice : .receipt
            return (.life, type, "Merchant")
        } else if contains(["advisory", "odometer", "service"]){
            return (.car, .serviceRepair, "Service Centre")
        } else if contains(["itinerary", "booking reference", "pnr"]) {
            return (.life, .travel, "Travel Provider")
        } else if contains(["tenancy", "letting", "landlord"]) {
            return (.home, .tenancy, "Landlord")
        } else if contains(["nhs", "medical", "patient"]) {
            return (.life, .medical, "Medical Provider")
        } else if contains(["university", "tuition", "degree"]) {
            return (.life, .education, "Education Provider")
        } else if contains(["passport", "visa", "government"]) {
            return (.life, .government, "Government")
        }
        return (.life, .other, "Document")
    }
}
