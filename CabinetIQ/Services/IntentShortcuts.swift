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

        return nil
    }

    private static func makeAnswer(query: String, text: String, document: DocumentEntity) -> AskAnswer {
        let citation = Citation(
            id: UUID(),
            documentID: document.id ?? UUID(),
            snippet: document.ocrText ?? document.displayTitle,
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
}
