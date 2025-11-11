import CoreData
import Foundation

enum IntentShortcuts {
    static func answer(query: String, context: NSManagedObjectContext) -> AskAnswer? {
        let lower = query.lowercased()
        if lower.contains("mot due") {
            let vrm = RegexExtractors.extractVRM(in: query)
            let doc = latestDoc(of: .mot, context: context, vrm: vrm)
            if let document = doc, let due = document.dueDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                let text = "MOT for \(document.issuer ?? "vehicle") expires on \(formatter.string(from: due))."
                let citation = Citation(id: UUID(), documentID: document.id ?? UUID(), snippet: document.ocrText ?? "", startOffset: 0)
                return AskAnswer(question: query, text: text, citations: [citation], source: .deterministic)
            }
        } else if lower.contains("mortgage rate") || lower.contains("fix end") {
            if let document = latestDoc(of: .mortgage, context: context, vrm: nil), let rate = document.extractedFields?.mortgage?.rate, let fixEnd = document.extractedFields?.mortgage?.fixEnd {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                let text = "Mortgage rate is \(rate)% fixed until \(formatter.string(from: fixEnd))."
                let citation = Citation(id: UUID(), documentID: document.id ?? UUID(), snippet: document.ocrText ?? "", startOffset: 0)
                return AskAnswer(question: query, text: text, citations: [citation], source: .deterministic)
            }
        } else if lower.contains("insurance due") {
            if let document = latestDoc(of: .insurance, context: context, vrm: RegexExtractors.extractVRM(in: query)), let due = document.dueDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                let text = "Insurance expires on \(formatter.string(from: due))."
                let citation = Citation(id: UUID(), documentID: document.id ?? UUID(), snippet: document.ocrText ?? "", startOffset: 0)
                return AskAnswer(question: query, text: text, citations: [citation], source: .deterministic)
            }
        }
        return nil
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
