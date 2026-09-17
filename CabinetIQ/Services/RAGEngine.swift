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
            return AskAnswer(question: question, text: "No documents matched.", citations: [], source: .deterministic)
        }
        var snippets: [String] = []
        var citations: [Citation] = []

        for (docID, _, snippet) in matches {
            let citation = Citation(id: UUID(), documentID: docID, snippet: snippet, startOffset: (SearchIndex.shared.vectors[docID]?.text.distance(of: snippet) ?? 0))
            citations.append(citation)
            snippets.append(snippet)
        }

        let corpus = snippets.joined(separator: "\n---\n")
        if fmToggleEnabled, let fmResponse = try? await fm.answer(question: question, context: corpus) {
            return AskAnswer(question: question, text: fmResponse, citations: citations, source: .rag)
        }

        let retrieved = buildDeterministicAnswer(question: question, matches: matches)
        return AskAnswer(question: question, text: retrieved, citations: citations, source: .rag)
    }

    private func buildDeterministicAnswer(question: String, matches: [(UUID, Double, String)]) -> String {
        guard let best = matches.first else { return "No matching text." }
        if question.lowercased().contains("when") || question.lowercased().contains("date") {
            return "Closest match: \(best.2)"
        }
        if question.lowercased().contains("amount") || question.lowercased().contains("how much") {
            return "Amount context: \(best.2)"
        }
        return best.2
    }
}

private extension String {
    func distance(of snippet: String) -> Int {
        guard let range = self.range(of: snippet) else { return 0 }
        return distance(from: startIndex, to: range.lowerBound)
    }
}
