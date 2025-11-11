import Foundation

@MainActor
final class FieldExtractor {
    static let shared = FieldExtractor()

    var useOnDeviceFM = false
    private let fm: OnDeviceFoundationModeling

    init(fm: OnDeviceFoundationModeling = OnDeviceFM()) {
        self.fm = fm
    }

    func extract(for type: DocType, text: String) async -> ExtractedFields {
        var fields = ExtractedFields()
        switch type {
        case .mot: fields = parseMOT(text: text)
        case .insurance: fields = parseInsurance(text: text)
        case .mortgage: fields = parseMortgage(text: text)
        case .utility: fields = parseUtility(text: text)
        case .taxHMRC: fields = parseTax(text: text)
        case .bankStatement: fields = parseBank(text: text)
        case .warranty: fields = parseWarranty(text: text)
        case .receipt, .invoice: fields = parseReceipt(text: text)
        case .serviceRepair: fields = parseService(text: text)
        default: fields = parseGeneric(text: text)
        }

        if useOnDeviceFM, let fmFields = await extractViaFM(type: type, text: text) {
            fields = merge(primary: fields, fallback: fmFields)
        }
        return fields
    }

    private func parseMOT(text: String) -> ExtractedFields {
        var fields = ExtractedFields()
        var mot = MOTFields()
        mot.vrm = RegexExtractors.extractVRM(in: text)
        mot.testDate = RegexExtractors.firstDate(matching: "test", in: text)
        mot.expiryDate = RegexExtractors.firstDate(matching: "expiry", in: text)
        if let digits = RegexExtractors.firstMatch(pattern: "odometer[\\s:]+([0-9,]+)", text: text)?.onlyDigits() {
            mot.odometerMiles = Int(digits)
        }
        mot.advisories = RegexExtractors.collectSection(named: "advisories", in: text)
        mot.defects = RegexExtractors.collectSection(named: "defects", in: text)
        mot.tyreNotes = mot.advisories.filter { $0.lowercased().contains("tyre") }

        fields.issueDate = mot.testDate
        fields.dueDate = mot.expiryDate
        fields.reference = RegexExtractors.extractPolicyNumber(in: text)
        fields.amountGBP = RegexExtractors.extractAmount(in: text)
        fields.mot = mot
        validateMOT(&fields)
        return fields
    }

    private func parseInsurance(text: String) -> ExtractedFields {
        var fields = ExtractedFields()
        var payload = InsuranceFields()
        payload.policyNumber = RegexExtractors.extractPolicyNumber(in: text)
        payload.policyStart = RegexExtractors.firstDate(matching: "start", in: text)
        payload.policyEnd = RegexExtractors.firstDate(matching: "end", in: text)
        payload.premium = RegexExtractors.extractAmount(in: text)
        payload.subject = RegexExtractors.extractVRM(in: text)
        fields.policyNumber = payload.policyNumber
        fields.issueDate = payload.policyStart
        fields.dueDate = payload.policyEnd
        fields.amountGBP = payload.premium
        fields.insurance = payload
        return fields
    }

    private func parseMortgage(text: String) -> ExtractedFields {
        var fields = ExtractedFields()
        var payload = MortgageFields()
        payload.lender = RegexExtractors.firstMatch(pattern: "lender[#: ]+([A-Za-z0-9 &]+)", text: text)
        payload.productName = RegexExtractors.firstMatch(pattern: "product[#: ]+([A-Za-z0-9 &]+)", text: text)
        payload.rate = RegexExtractors.firstMatch(pattern: "([0-9]{1,2}\\.[0-9]{1,2})%", text: text).flatMap(Double.init)
        payload.fixEnd = RegexExtractors.firstDate(matching: "fixed", in: text)
        payload.monthlyPayment = RegexExtractors.firstMatch(pattern: "monthly payment[#: ]+£([0-9,.]+)", text: text)?.asDecimal()
        payload.balance = RegexExtractors.extractAmount(in: text)
        fields.mortgage = payload
        fields.issueDate = RegexExtractors.firstDate(matching: "statement", in: text)
        fields.dueDate = payload.fixEnd
        fields.amountGBP = payload.balance
        fields.reference = payload.productName
        return fields
    }

    private func parseUtility(text: String) -> ExtractedFields {
        var fields = ExtractedFields()
        var payload = UtilityFields()
        payload.mpan = RegexExtractors.extractMPAN(in: text)
        payload.mprn = RegexExtractors.extractMPRN(in: text)
        payload.unitRate = RegexExtractors.firstMatch(pattern: "unit rate[#: ]+([0-9]+\\.?[0-9]*)p", text: text)?.asDecimal()
        payload.standingCharge = RegexExtractors.firstMatch(pattern: "standing charge[#: ]+([0-9]+\\.?[0-9]*)p", text: text)?.asDecimal()
        payload.accountNo = RegexExtractors.extractAccountNumber(in: text)
        fields.utility = payload
        fields.issueDate = RegexExtractors.firstDate(matching: "issued", in: text)
        fields.dueDate = RegexExtractors.firstDate(matching: "due", in: text)
        fields.amountGBP = RegexExtractors.extractAmount(in: text)
        fields.accountNumber = payload.accountNo
        return fields
    }

    private func parseTax(text: String) -> ExtractedFields {
        var fields = ExtractedFields()
        var payload = TaxFields()
        payload.taxYear = RegexExtractors.firstMatch(pattern: "tax year[#: ]+([0-9/ -]+)", text: text)
        payload.paymentRef = RegexExtractors.firstMatch(pattern: "payment reference[#: ]+([A-Z0-9 ]+)", text: text)
        payload.amountDue = RegexExtractors.extractAmount(in: text)
        payload.deadline = RegexExtractors.firstDate(matching: "deadline", in: text)
        fields.tax = payload
        fields.reference = payload.paymentRef
        fields.amountGBP = payload.amountDue
        fields.dueDate = payload.deadline
        return fields
    }

    private func parseBank(text: String) -> ExtractedFields {
        var fields = ExtractedFields()
        var payload = BankStatementFields()
        payload.sortCode = RegexExtractors.extractSortCode(in: text)
        payload.accountNumber = RegexExtractors.extractAccountNumber(in: text)
        payload.periodStart = RegexExtractors.firstDate(matching: "from", in: text)
        payload.periodEnd = RegexExtractors.firstDate(matching: "to", in: text)
        payload.closingBalance = RegexExtractors.extractAmount(in: text)
        fields.bank = payload
        fields.issueDate = payload.periodEnd
        fields.amountGBP = payload.closingBalance
        fields.accountNumber = payload.accountNumber
        return fields
    }

    private func parseWarranty(text: String) -> ExtractedFields {
        var fields = ExtractedFields()
        var payload = WarrantyFields()
        payload.product = RegexExtractors.firstMatch(pattern: "product[#: ]+([A-Za-z0-9 -]+)", text: text)
        payload.serial = RegexExtractors.firstMatch(pattern: "serial[#: ]+([A-Za-z0-9-]+)", text: text)
        payload.warrantyStart = RegexExtractors.firstDate(matching: "start", in: text)
        payload.warrantyEnd = RegexExtractors.firstDate(matching: "end", in: text)
        fields.warranty = payload
        fields.issueDate = payload.warrantyStart
        fields.dueDate = payload.warrantyEnd
        fields.reference = payload.serial
        return fields
    }

    private func parseReceipt(text: String) -> ExtractedFields {
        var fields = ExtractedFields()
        var payload = ReceiptFields()
        payload.merchant = RegexExtractors.firstMatch(pattern: "merchant[#: ]+([A-Za-z0-9 &]+)", text: text)
        payload.vat = RegexExtractors.firstMatch(pattern: "vat[#: ]+£([0-9,.]+)", text: text)?.asDecimal()
        payload.total = RegexExtractors.extractAmount(in: text)
        payload.paymentMethod = RegexExtractors.firstMatch(pattern: "payment method[#: ]+([A-Za-z0-9 ]+)", text: text)
        fields.receipt = payload
        fields.issueDate = RegexExtractors.firstDate(matching: "date", in: text)
        fields.amountGBP = payload.total
        fields.counterparty = payload.merchant
        return fields
    }

    private func parseService(text: String) -> ExtractedFields {
        var fields = ExtractedFields()
        var payload = ServiceRepairFields()
        payload.vehicleVRM = RegexExtractors.extractVRM(in: text)
        if let digits = RegexExtractors.firstMatch(pattern: "mileage[#: ]+([0-9,]+)", text: text)?.onlyDigits() {
            payload.mileage = Int(digits)
        }
        payload.items = RegexExtractors.collectSection(named: "items", in: text, maxLines: 10)
        payload.advisories = RegexExtractors.collectSection(named: "advisory", in: text, maxLines: 10)
        fields.service = payload
        fields.issueDate = RegexExtractors.firstDate(matching: "service", in: text)
        fields.dueDate = RegexExtractors.firstDate(matching: "due", in: text)
        fields.amountGBP = RegexExtractors.extractAmount(in: text)
        fields.policyNumber = payload.vehicleVRM
        return fields
    }

    private func parseGeneric(text: String) -> ExtractedFields {
        var fields = ExtractedFields()
        fields.issueDate = RegexExtractors.firstDate(matching: "issue", in: text)
        fields.dueDate = RegexExtractors.firstDate(matching: "due", in: text)
        fields.amountGBP = RegexExtractors.extractAmount(in: text)
        fields.reference = RegexExtractors.extractPolicyNumber(in: text)
        return fields
    }

    private func merge(primary: ExtractedFields, fallback: ExtractedFields) -> ExtractedFields {
        var merged = primary
        if merged.issueDate == nil { merged.issueDate = fallback.issueDate }
        if merged.dueDate == nil { merged.dueDate = fallback.dueDate }
        if merged.amountGBP == nil { merged.amountGBP = fallback.amountGBP }
        if merged.reference == nil { merged.reference = fallback.reference }
        if merged.accountNumber == nil { merged.accountNumber = fallback.accountNumber }
        if merged.policyNumber == nil { merged.policyNumber = fallback.policyNumber }
        if merged.counterparty == nil { merged.counterparty = fallback.counterparty }
        if merged.address == nil { merged.address = fallback.address }
        merged.mot = merged.mot ?? fallback.mot
        merged.insurance = merged.insurance ?? fallback.insurance
        merged.mortgage = merged.mortgage ?? fallback.mortgage
        merged.utility = merged.utility ?? fallback.utility
        merged.tax = merged.tax ?? fallback.tax
        merged.bank = merged.bank ?? fallback.bank
        merged.warranty = merged.warranty ?? fallback.warranty
        merged.receipt = merged.receipt ?? fallback.receipt
        merged.service = merged.service ?? fallback.service
        return merged
    }

    private func extractViaFM(type: DocType, text: String) async -> ExtractedFields? {
        do {
            let data = try await fm.extractJSON(for: type, from: text)
            guard !data.isEmpty else { return nil }
            return try JSONDecoder().decode(ExtractedFields.self, from: data)
        } catch {
            return nil
        }
    }

    private func validateMOT(_ fields: inout ExtractedFields) {
        guard var mot = fields.mot, let test = mot.testDate else { return }
        if mot.expiryDate == nil, let expiry = Calendar.current.date(byAdding: .year, value: 1, to: test) {
            mot.expiryDate = expiry
            fields.dueDate = expiry
        }
        fields.mot = mot
    }
}

private extension String {
    func onlyDigits() -> String { filter { $0.isNumber } }
    func asDecimal() -> Decimal? {
        Decimal(string: self.replacingOccurrences(of: ",", with: ""))
    }
}
