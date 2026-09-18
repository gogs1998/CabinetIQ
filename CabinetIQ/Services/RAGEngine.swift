import Foundation
import CoreData

@MainActor
final class RAGEngine: ObservableObject {
    static let shared = RAGEngine()

    @Published var fmToggleEnabled = false
    private let fm: OnDeviceFoundationModeling

    init(fm: OnDeviceFoundationModeling = OnDeviceFM()) {
        self.fm = fm
    }

    func answer(question: String, scope: AskScope = .all, context: NSManagedObjectContext) async -> AskAnswer {
        let matches = SearchIndex.shared.topMatches(for: question, limit: 5, scope: scope)
        guard !matches.isEmpty else {
            return AskAnswer(
                question: question,
                text: "I couldn’t find that in the text we read. Try a plate, policy number, issuer, or amount.",
                citations: [],
                source: .rag
            )
        }

        if let structured = structuredAnswer(question: question, documentIDs: matches.map(\.0), context: context) {
            return structured
        }

        var snippets: [String] = []
        var citations: [Citation] = []
        var attributed: [(DocumentEntity, String)] = []

        for (docID, _, snippet) in matches {
            let citation = Citation(
                id: UUID(),
                documentID: docID,
                snippet: snippet,
                startOffset: (SearchIndex.shared.vectors[docID]?.text.distance(of: snippet) ?? 0)
            )
            citations.append(citation)
            snippets.append(snippet)
            if let document = fetchDocument(id: docID, context: context) {
                attributed.append((document, snippet))
            }
        }

        let corpus = snippets.joined(separator: "\n---\n")
        if fmToggleEnabled, let fmResponse = try? await fm.answer(question: question, context: corpus) {
            return AskAnswer(question: question, text: fmResponse, citations: citations, source: .rag)
        }

        let text = composedAnswer(question: question, hits: attributed)
        return AskAnswer(question: question, text: text, citations: citations, source: .rag)
    }

    private func structuredAnswer(question: String, documentIDs: [UUID], context: NSManagedObjectContext) -> AskAnswer? {
        let tokens = question
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count > 2 && !["what", "whats", "which", "this", "that", "have", "does", "from"].contains($0) }
        guard !tokens.isEmpty else { return nil }

        for id in documentIDs {
            guard let document = fetchDocument(id: id, context: context) else { continue }
            for row in document.fieldRows {
                let label = row.label.lowercased()
                if tokens.contains(where: { label.contains($0) }) {
                    let citation = Citation(
                        id: UUID(),
                        documentID: id,
                        snippet: document.ocrPreview.isEmpty ? row.value : document.ocrPreview,
                        startOffset: 0
                    )
                    return AskAnswer(
                        question: question,
                        text: "\(row.label) on \(document.displayTitle) is \(row.value).",
                        citations: [citation],
                        source: .rag
                    )
                }
            }
        }
        return nil
    }

    private func composedAnswer(question: String, hits: [(DocumentEntity, String)]) -> String {
        guard let best = hits.first else { return "No matching text." }
        let source = "From the text we read on \(best.0.displayTitle) (\(best.0.docTypeValue.displayName))"
        let snippet = best.1.trimmingCharacters(in: .whitespacesAndNewlines)
        if question.lowercased().contains("when") || question.lowercased().contains("date") {
            return "\(source):\n\(snippet)"
        }
        if question.lowercased().contains("amount") || question.lowercased().contains("how much") {
            return "\(source):\n\(snippet)"
        }
        if hits.count == 1 {
            return "\(source):\n\(snippet)"
        }
        let extras = hits.dropFirst().prefix(2).map { "• \($0.0.displayTitle): \($0.1.trimmingCharacters(in: .whitespacesAndNewlines))" }
        return "\(source):\n\(snippet)\n\nAlso mentioned in:\n\(extras.joined(separator: "\n"))"
    }

    private func fetchDocument(id: UUID, context: NSManagedObjectContext) -> DocumentEntity? {
        let request: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequestAll()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
}

private extension String {
    func distance(of snippet: String) -> Int {
        guard let range = self.range(of: snippet) else { return 0 }
        return distance(from: startIndex, to: range.lowerBound)
    }
}
