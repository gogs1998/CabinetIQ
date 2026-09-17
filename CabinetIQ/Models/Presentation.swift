import Foundation

enum DueStatus: Equatable {
    case overdue(days: Int)
    case dueSoon(days: Int)
    case upcoming(days: Int)
    case clear
    case none

    static let soonWindow = 30
    static let upcomingWindow = 90

    static func from(dueDate: Date?, now: Date = Date(), calendar: Calendar = .current) -> DueStatus {
        guard let dueDate else { return .none }
        let start = calendar.startOfDay(for: now)
        let end = calendar.startOfDay(for: dueDate)
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        if days < 0 { return .overdue(days: abs(days)) }
        if days <= soonWindow { return .dueSoon(days: days) }
        if days <= upcomingWindow { return .upcoming(days: days) }
        return .clear
    }

    var attentionRank: Int {
        switch self {
        case .overdue: return 0
        case .dueSoon: return 1
        case .upcoming: return 2
        case .clear: return 3
        case .none: return 4
        }
    }

    var needsAttention: Bool {
        switch self {
        case .overdue, .dueSoon, .upcoming: return true
        case .clear, .none: return false
        }
    }

    var label: String {
        switch self {
        case .overdue(let days):
            return days == 1 ? "Overdue yesterday" : "Overdue by \(days) days"
        case .dueSoon(let days):
            if days == 0 { return "Due today" }
            if days == 1 { return "Due tomorrow" }
            return "Due in \(days) days"
        case .upcoming(let days):
            return "Due in \(days) days"
        case .clear:
            return "In date"
        case .none:
            return "No date"
        }
    }

    var shortLabel: String {
        switch self {
        case .overdue(let days): return "\(days)d overdue"
        case .dueSoon(let days): return days == 0 ? "Today" : "\(days)d"
        case .upcoming(let days): return "\(days)d"
        case .clear: return "In date"
        case .none: return "—"
        }
    }
}

struct FieldRow: Identifiable, Equatable {
    let id: String
    let label: String
    let value: String
}

enum FieldCatalog {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "en_GB")
        return formatter
    }()

    static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_GB")
        return formatter
    }()

    static func money(_ amount: Decimal?) -> String? {
        guard let amount else { return nil }
        return currencyFormatter.string(from: amount as NSDecimalNumber)
    }

    static func date(_ value: Date?) -> String? {
        guard let value else { return nil }
        return dateFormatter.string(from: value)
    }

    static func rows(from fields: ExtractedFields) -> [FieldRow] {
        var rows: [FieldRow] = []

        func add(_ id: String, _ label: String, _ value: String?) {
            guard let value else { return }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            rows.append(FieldRow(id: id, label: label, value: trimmed))
        }

        add("issue", "Issued", date(fields.issueDate))
        add("due", "Due", date(fields.dueDate))
        add("amount", "Amount", money(fields.amountGBP))
        add("reference", "Reference", fields.reference)
        add("account", "Account", fields.accountNumber)
        add("policy", "Policy number", fields.policyNumber)
        add("counterparty", "Counterparty", fields.counterparty)
        add("address", "Address", fields.address)

        if let mot = fields.mot {
            add("vrm", "Registration", mot.vrm)
            add("testDate", "Test date", date(mot.testDate))
            add("motExpiry", "MOT expiry", date(mot.expiryDate))
            if let miles = mot.odometerMiles {
                add("odometer", "Odometer", "\(miles.formatted()) miles")
            }
            if !mot.advisories.isEmpty {
                add("advisories", "Advisories", mot.advisories.joined(separator: " · "))
            }
            if !mot.defects.isEmpty {
                add("defects", "Defects", mot.defects.joined(separator: " · "))
            }
        }

        if let insurance = fields.insurance {
            add("insStart", "Policy start", date(insurance.policyStart))
            add("insEnd", "Policy end", date(insurance.policyEnd))
            add("premium", "Premium", money(insurance.premium))
            add("insPolicy", "Policy number", insurance.policyNumber)
            add("subject", "Covered", insurance.subject)
        }

        if let mortgage = fields.mortgage {
            add("lender", "Lender", mortgage.lender)
            add("product", "Product", mortgage.productName)
            if let rate = mortgage.rate {
                add("rate", "Rate", String(format: "%.2f%%", rate))
            }
            add("fixEnd", "Fixed until", date(mortgage.fixEnd))
            add("payment", "Monthly payment", money(mortgage.monthlyPayment))
            add("balance", "Balance", money(mortgage.balance))
        }

        if let utility = fields.utility {
            add("supply", "Supply", utility.supplyType)
            add("tariff", "Tariff", utility.tariff)
            add("unitRate", "Unit rate", money(utility.unitRate))
            add("standing", "Standing charge", money(utility.standingCharge))
            add("mpan", "MPAN", utility.mpan)
            add("mprn", "MPRN", utility.mprn)
            add("utilAccount", "Account", utility.accountNo)
        }

        if let tax = fields.tax {
            add("taxYear", "Tax year", tax.taxYear)
            add("taxDue", "Amount due", money(tax.amountDue))
            add("paymentRef", "Payment reference", tax.paymentRef)
            add("deadline", "Deadline", date(tax.deadline))
        }

        if let bank = fields.bank {
            add("sortCode", "Sort code", bank.sortCode)
            add("bankAccount", "Account number", bank.accountNumber)
            add("periodStart", "Period start", date(bank.periodStart))
            add("periodEnd", "Period end", date(bank.periodEnd))
            add("closing", "Closing balance", money(bank.closingBalance))
        }

        if let warranty = fields.warranty {
            add("productName", "Product", warranty.product)
            add("serial", "Serial", warranty.serial)
            add("warrantyStart", "Warranty start", date(warranty.warrantyStart))
            add("warrantyEnd", "Warranty end", date(warranty.warrantyEnd))
        }

        if let receipt = fields.receipt {
            add("merchant", "Merchant", receipt.merchant)
            add("vat", "VAT", money(receipt.vat))
            add("total", "Total", money(receipt.total))
            add("paymentMethod", "Paid with", receipt.paymentMethod)
        }

        if let service = fields.service {
            add("serviceVRM", "Registration", service.vehicleVRM)
            if let mileage = service.mileage {
                add("serviceMiles", "Mileage", "\(mileage.formatted()) miles")
            }
            if !service.items.isEmpty {
                add("serviceItems", "Work done", service.items.joined(separator: " · "))
            }
            if !service.advisories.isEmpty {
                add("serviceAdv", "Advisories", service.advisories.joined(separator: " · "))
            }
        }

        var seen = Set<String>()
        return rows.filter { seen.insert("\($0.label)|\($0.value)").inserted }
    }
}

struct CoverageSnapshot: Equatable {
    let domain: Domain
    let count: Int
    let headline: String
    let status: DueStatus
}

enum VaultInsights {
    static func attentionItems(in documents: [DocumentEntity], now: Date = Date(), limit: Int = 4) -> [DocumentEntity] {
        documents
            .filter { DueStatus.from(dueDate: $0.dueDate, now: now).needsAttention }
            .sorted { lhs, rhs in
                let left = DueStatus.from(dueDate: lhs.dueDate, now: now)
                let right = DueStatus.from(dueDate: rhs.dueDate, now: now)
                if left.attentionRank != right.attentionRank {
                    return left.attentionRank < right.attentionRank
                }
                return (lhs.dueDate ?? .distantFuture) < (rhs.dueDate ?? .distantFuture)
            }
            .prefix(limit)
            .map { $0 }
    }

    static func coverage(for domain: Domain, in documents: [DocumentEntity], now: Date = Date()) -> CoverageSnapshot {
        let filtered = documents.filter { $0.domainValue == domain }
        let worst = filtered
            .map { DueStatus.from(dueDate: $0.dueDate, now: now) }
            .min(by: { $0.attentionRank < $1.attentionRank }) ?? .none

        let headline: String
        if filtered.isEmpty {
            headline = "Nothing filed yet"
        } else if worst.needsAttention {
            headline = worst.label
        } else {
            headline = filtered.count == 1 ? "1 document" : "\(filtered.count) documents"
        }

        return CoverageSnapshot(domain: domain, count: filtered.count, headline: headline, status: worst)
    }

    static func suggestedQuestions(types: Set<DocType>, isEmpty: Bool) -> [String] {
        if isEmpty {
            return [
                "When does my MOT expire?",
                "What bills are due this month?",
                "What is my mortgage rate?"
            ]
        }

        var questions: [String] = []
        if types.contains(.mot) { questions.append("When does my MOT expire?") }
        if types.contains(.insurance) { questions.append("When is insurance due?") }
        if types.contains(.mortgage) { questions.append("What is my mortgage rate?") }
        if types.contains(.taxHMRC) { questions.append("When is my tax deadline?") }
        if types.contains(.utility) { questions.append("What bills do I have?") }
        if types.contains(.warranty) { questions.append("Which warranties are still active?") }
        questions.append("What needs my attention?")
        return questions
    }

    static func suggestedQuestions(for documents: [DocumentEntity]) -> [String] {
        suggestedQuestions(types: Set(documents.map(\.docTypeValue)), isEmpty: documents.isEmpty)
    }

    static func greeting(at date: Date = Date(), calendar: Calendar = .current) -> String {
        switch calendar.component(.hour, from: date) {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    static func ingestSummary(for document: DocumentEntity) -> String {
        let title = document.displayTitle
        if let due = FieldCatalog.date(document.dueDate) {
            return "\(title) filed. Due \(due) — we'll remind you."
        }
        return "\(title) is in your cabinet."
    }
}

enum BundledSamples {
    static func text(named name: String) -> String? {
        let urls = [
            Bundle.main.url(forResource: name, withExtension: "txt", subdirectory: "Fixtures"),
            Bundle.main.url(forResource: name, withExtension: "txt")
        ].compactMap { $0 }
        if let url = urls.first, let contents = try? String(contentsOf: url) {
            return contents
        }
        if name == "mot_sample" { return mot }
        return nil
    }

    static let mot = """
    MOT Test Certificate
    Vehicle: CAB123
    Test Date: 14/03/2024
    Expiry Date: 13/03/2025
    Odometer: 45,678 miles
    Advisories
    Nearside tyre nearing limit
    """
}
