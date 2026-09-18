import CoreData
import Foundation

enum IntentShortcuts {
    static func answer(query: String, context: NSManagedObjectContext) -> AskAnswer? {
        let lower = query.lowercased()

        if mentions(["mot"], in: lower) && mentionsAny(["due", "expir", "when"], in: lower) {
            let vrm = RegexExtractors.extractVRM(in: query)
            if let document = latestDoc(of: .mot, context: context, vrm: vrm), let due = document.dueDate {
                return makeAnswer(
                    query: query,
                    text: "MOT for \(document.displayTitle) expires on \(FieldCatalog.date(due) ?? due.formatted(date: .abbreviated, time: .omitted)).",
                    document: document
                )
            }
        }

        if mentions(["mortgage"], in: lower) && mentionsAny(["rate", "fix", "fixed"], in: lower) {
            if let document = latestDoc(of: .mortgage, context: context, vrm: nil),
               let mortgage = document.extractedFields?.mortgage,
               let rate = mortgage.rate,
               let fixEnd = mortgage.fixEnd {
                return makeAnswer(
                    query: query,
                    text: "Mortgage rate is \(String(format: "%.2f%%", rate)) fixed until \(FieldCatalog.date(fixEnd) ?? "").",
                    document: document
                )
            }
        }

        if mentions(["mortgage"], in: lower) && mentionsAny(["payment", "monthly"], in: lower) {
            if let document = latestDoc(of: .mortgage, context: context, vrm: nil),
               let payment = document.extractedFields?.mortgage?.monthlyPayment,
               let money = FieldCatalog.money(payment) {
                return makeAnswer(query: query, text: "Monthly mortgage payment is \(money).", document: document)
            }
        }

        if mentions(["insurance"], in: lower) && mentionsAny(["due", "expir", "when", "renew"], in: lower) {
            if let document = latestDoc(of: .insurance, context: context, vrm: RegexExtractors.extractVRM(in: query)),
               let due = document.dueDate {
                return makeAnswer(
                    query: query,
                    text: "Insurance expires on \(FieldCatalog.date(due) ?? due.formatted(date: .abbreviated, time: .omitted)).",
                    document: document
                )
            }
        }

        if mentions(["tax"], in: lower) && mentionsAny(["due", "deadline", "when"], in: lower) {
            if let document = latestDoc(of: .taxHMRC, context: context, vrm: nil),
               let due = document.dueDate ?? document.extractedFields?.tax?.deadline {
                return makeAnswer(
                    query: query,
                    text: "HMRC tax is due on \(FieldCatalog.date(due) ?? due.formatted(date: .abbreviated, time: .omitted)).",
                    document: document
                )
            }
        }

        if mentionsAny(["registration", "reg plate", "number plate", "vrm", "plate"], in: lower) {
            if let match = firstDocument(in: context, where: { $0.extractedFields?.mot?.vrm ?? $0.extractedFields?.service?.vehicleVRM }) {
                return makeAnswer(
                    query: query,
                    text: "Registration on \(match.document.displayTitle) is \(match.value).",
                    document: match.document
                )
            }
        }

        if mentionsAny(["policy number", "policy no"], in: lower)
            || (mentions(["policy"], in: lower) && mentionsAny(["number", "ref"], in: lower)) {
            if let match = firstDocument(in: context, where: {
                $0.extractedFields?.policyNumber ?? $0.extractedFields?.insurance?.policyNumber
            }) {
                return makeAnswer(
                    query: query,
                    text: "Policy number on \(match.document.displayTitle) is \(match.value).",
                    document: match.document
                )
            }
        }

        if mentionsAny(["how much", "premium", "amount", "cost", "owe"], in: lower) {
            if let document = latestWithAmount(context: context),
               let money = FieldCatalog.money(document.amount?.decimalValue ?? document.extractedFields?.amountGBP) {
                return makeAnswer(
                    query: query,
                    text: "\(document.displayTitle) is \(money).",
                    document: document
                )
            }
        }

        if mentionsAny(["account number", "sort code", "mpan", "mprn"], in: lower) {
            if let match = firstField(matchingLabels: ["account", "sort code", "mpan", "mprn"], context: context) {
                return makeAnswer(
                    query: query,
                    text: "\(match.row.label) on \(match.document.displayTitle) is \(match.row.value).",
                    document: match.document
                )
            }
        }

        if mentionsAny(["odometer", "mileage", "miles"], in: lower) {
            if let match = firstDocument(in: context, where: { fields in
                fields.extractedFields?.mot?.odometerMiles.map { "\($0.formatted()) miles" }
                    ?? fields.extractedFields?.service?.mileage.map { "\($0.formatted()) miles" }
            }) {
                return makeAnswer(
                    query: query,
                    text: "Odometer on \(match.document.displayTitle) is \(match.value).",
                    document: match.document
                )
            }
        }

        if mentionsAny(["lender", "who do i owe"], in: lower) {
            if let match = firstDocument(in: context, where: { $0.extractedFields?.mortgage?.lender }) {
                return makeAnswer(
                    query: query,
                    text: "Lender on \(match.document.displayTitle) is \(match.value).",
                    document: match.document
                )
            }
        }

        if mentionsAny(["attention", "renew soon", "coming up"], in: lower) || (mentions(["due"], in: lower) && mentionsAny(["soon", "month"], in: lower)) {
            let request: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequestAll()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \DocumentEntity.dueDate, ascending: true)]
            let docs = (try? context.fetch(request)) ?? []
            let upcoming = VaultInsights.attentionItems(in: docs, limit: 5)
            if !upcoming.isEmpty {
                let lines = upcoming.map { document in
                    let status = DueStatus.from(dueDate: document.dueDate)
                    return "• \(document.displayTitle) — \(status.label)"
                }.joined(separator: "\n")
                let citations = upcoming.compactMap { document -> Citation? in
                    guard let id = document.id else { return nil }
                    return Citation(id: UUID(), documentID: id, snippet: document.ocrText ?? document.displayTitle, startOffset: 0)
                }
                return AskAnswer(question: query, text: "Here’s what needs you:\n\(lines)", citations: citations, source: .deterministic)
            }
        }

        if mentions(["warranty"], in: lower) {
            if let document = latestDoc(of: .warranty, context: context, vrm: nil) {
                let end = document.dueDate ?? document.extractedFields?.warranty?.warrantyEnd
                let product = document.extractedFields?.warranty?.product ?? document.displayTitle
                let text = end == nil
                    ? "I found a warranty for \(product)."
                    : "Warranty for \(product) runs until \(FieldCatalog.date(end) ?? "")."
                return makeAnswer(query: query, text: text, document: document)
            }
        }

        if mentionsAny(["what is", "what's", "whats", "which"], in: lower) {
            return answerFromFieldRows(query: query, context: context)
        }

        return nil
    }

    private static func makeAnswer(query: String, text: String, document: DocumentEntity) -> AskAnswer {
        let citation = Citation(
            id: UUID(),
            documentID: document.id ?? UUID(),
            snippet: document.ocrPreview.isEmpty ? document.displayTitle : document.ocrPreview,
            startOffset: 0
        )
        return AskAnswer(question: query, text: text, citations: [citation], source: .deterministic)
    }

    private static func mentions(_ terms: [String], in lower: String) -> Bool {
        terms.allSatisfy { lower.contains($0) }
    }

    private static func mentionsAny(_ terms: [String], in lower: String) -> Bool {
        terms.contains { lower.contains($0) }
    }

    private static func latestDoc(of type: DocType, context: NSManagedObjectContext, vrm: String?) -> DocumentEntity? {
        let request: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequestAll()
        var predicates: [NSPredicate] = [NSPredicate(format: "docType == %@", type.rawValue)]
        if let vrm {
            predicates.append(NSPredicate(format: "ocrText CONTAINS[cd] %@", vrm))
        }
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \DocumentEntity.dueDate, ascending: false)]
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private static func allDocuments(in context: NSManagedObjectContext) -> [DocumentEntity] {
        let request: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequestAll()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \DocumentEntity.createdAt, ascending: false)]
        return (try? context.fetch(request)) ?? []
    }

    private static func latestWithAmount(context: NSManagedObjectContext) -> DocumentEntity? {
        allDocuments(in: context).first { $0.amount != nil || $0.extractedFields?.amountGBP != nil }
    }

    private static func firstDocument(in context: NSManagedObjectContext, where value: (DocumentEntity) -> String?) -> (document: DocumentEntity, value: String)? {
        for document in allDocuments(in: context) {
            if let match = value(document), !match.isEmpty {
                return (document, match)
            }
        }
        return nil
    }

    private static func firstField(matchingLabels labels: [String], context: NSManagedObjectContext) -> (document: DocumentEntity, row: FieldRow)? {
        for document in allDocuments(in: context) {
            for row in document.fieldRows {
                let label = row.label.lowercased()
                if labels.contains(where: { label.contains($0) }) {
                    return (document, row)
                }
            }
        }
        return nil
    }

    private static func answerFromFieldRows(query: String, context: NSManagedObjectContext) -> AskAnswer? {
        let tokens = query
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count > 2 && !["what", "whats", "which", "this", "that", "have", "does"].contains($0) }
        guard !tokens.isEmpty else { return nil }

        var best: (DocumentEntity, FieldRow, Int)?
        for document in allDocuments(in: context) {
            for row in document.fieldRows {
                let labelTokens = row.label.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
                let labelHits = tokens.filter { token in labelTokens.contains { $0.contains(token) || token.contains($0) } }.count
                guard labelHits > 0 else { continue }
                if labelHits > (best?.2 ?? 0) {
                    best = (document, row, labelHits)
                }
            }
        }
        guard let best else { return nil }
        return makeAnswer(
            query: query,
            text: "\(best.1.label) on \(best.0.displayTitle) is \(best.1.value).",
            document: best.0
        )
    }
}
