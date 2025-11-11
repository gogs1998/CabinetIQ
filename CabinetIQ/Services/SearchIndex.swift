import Foundation
import CoreData

@MainActor
final class SearchIndex: ObservableObject {
    static let shared = SearchIndex()

    struct Vector {
        var terms: [String: Int]
        var length: Int
        var text: String
        var domain: Domain
        var docType: DocType
    }

    private(set) var vectors: [UUID: Vector] = [:]
    private var idfCache: [String: Double] = [:]
    private let storageURL: URL
    private var averageLength: Double {
        let total = vectors.values.map { $0.length }.reduce(0, +)
        return Double(total) / Double(max(1, vectors.count))
    }

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = base.appendingPathComponent("CabinetIQ", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        storageURL = directory.appendingPathComponent("search_index.json")
        loadPersistedVectors()
    }

    func bootstrapIfNeeded(context: NSManagedObjectContext) {
        guard vectors.isEmpty else { return }
        let request: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequestAll()
        if let docs = try? context.fetch(request) {
            docs.forEach { index(document: $0) }
        }
    }

    func index(document: DocumentEntity) {
        guard let identifier = document.id, let text = document.ocrText else { return }
        let tokens = tokenize(text)
        var counts: [String: Int] = [:]
        tokens.forEach { counts[$0, default: 0] += 1 }
        vectors[identifier] = Vector(terms: counts, length: tokens.count, text: text, domain: document.domainValue, docType: document.docTypeValue)
        idfCache.removeAll()
        persistVectors()
    }

    func remove(document: DocumentEntity) {
        guard let identifier = document.id else { return }
        vectors.removeValue(forKey: identifier)
        idfCache.removeAll()
        persistVectors()
    }

    func topMatches(for query: String, limit: Int = 5, scope: AskScope = .all) -> [(UUID, Double, String)] {
        let tokens = tokenize(query)
        guard !tokens.isEmpty else { return [] }
        var scores: [(UUID, Double, String)] = []
        for (id, vector) in vectors {
            guard matchesScope(vector: vector, scope: scope, documentID: id) else { continue }
            let score = bm25(tokens: tokens, vector: vector)
            guard score > 0 else { continue }
            let snippet = snippet(for: vector.text, tokens: tokens)
            scores.append((id, score, snippet))
        }
        return scores.sorted(by: { $0.1 > $1.1 }).prefix(limit).map { $0 }
    }

    private func matchesScope(vector: Vector, scope: AskScope, documentID: UUID) -> Bool {
        switch scope {
        case .all: return true
        case .domain(let domain): return vector.domain == domain
        case .docType(let type): return vector.docType == type
        case .document(let id): return documentID == id
        }
    }

    private func bm25(tokens: [String], vector: Vector, k1: Double = 1.5, b: Double = 0.75) -> Double {
        let docLength = Double(vector.length)
        var score = 0.0
        for token in tokens {
            let tf = Double(vector.terms[token] ?? 0)
            guard tf > 0 else { continue }
            let idf = self.idf(for: token)
            let denominator = tf + k1 * (1 - b + b * (docLength / max(1.0, averageLength)))
            score += idf * (tf * (k1 + 1)) / denominator
        }
        return score
    }

    private func idf(for token: String) -> Double {
        if let cached = idfCache[token] { return cached }
        let df = vectors.values.filter { $0.terms[token] != nil }.count
        let idf = log((Double(vectors.count - df + 1) / Double(df + 1)) + 1)
        idfCache[token] = idf
        return idf
    }

    private func snippet(for text: String, tokens: [String]) -> String {
        let lower = text.lowercased()
        var bestRange: Range<String.Index>?
        for token in tokens {
            if let range = lower.range(of: token), bestRange == nil || range.lowerBound < bestRange!.lowerBound {
                bestRange = range
            }
        }
        if let range = bestRange {
            let start = text.index(range.lowerBound, offsetBy: -30, limitedBy: text.startIndex) ?? text.startIndex
            let end = text.index(range.upperBound, offsetBy: 120, limitedBy: text.endIndex) ?? text.endIndex
            return String(text[start..<end])
        }
        return String(text.prefix(160))
    }

    private func tokenize(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    private func loadPersistedVectors() {
        guard let data = try? Data(contentsOf: storageURL) else { return }
        do {
            let decoded = try JSONDecoder().decode([String: PersistedVector].self, from: data)
            vectors = decoded.reduce(into: [:]) { partialResult, entry in
                guard let id = UUID(uuidString: entry.key),
                      let domain = Domain(rawValue: entry.value.domain),
                      let docType = DocType(rawValue: entry.value.docType) else { return }
                partialResult[id] = Vector(terms: entry.value.terms,
                                           length: entry.value.length,
                                           text: entry.value.text,
                                           domain: domain,
                                           docType: docType)
            }
        } catch {
            try? FileManager.default.removeItem(at: storageURL)
        }
    }

    private func persistVectors() {
        let payload = vectors.reduce(into: [String: PersistedVector]()) { partialResult, element in
            let vector = element.value
            partialResult[element.key.uuidString] = PersistedVector(terms: vector.terms,
                                                                    length: vector.length,
                                                                    text: vector.text,
                                                                    domain: vector.domain.rawValue,
                                                                    docType: vector.docType.rawValue)
        }
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private struct PersistedVector: Codable {
        let terms: [String: Int]
        let length: Int
        let text: String
        let domain: String
        let docType: String
    }
}
