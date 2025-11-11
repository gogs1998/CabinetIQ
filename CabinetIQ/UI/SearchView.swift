import SwiftUI
import CoreData

struct SearchView: View {
    @Environment(\.managedObjectContext) private var context
    @State private var query = ""
    @State private var results: [(UUID, Double, String)] = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(results, id: \.0) { result in
                    if let document = fetchDocument(id: result.0) {
                        NavigationLink(destination: DocumentDetailView(document: document)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(document.issuer ?? "Untitled")
                                    .font(.headline)
                                Text(result.2)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Search")
            .searchable(text: $query)
            .onChange(of: query) { _, newValue in
                runSearch(text: newValue)
            }
        }
    }

    private func runSearch(text: String) {
        guard text.count >= 2 else {
            results = []
            return
        }
        results = SearchIndex.shared.topMatches(for: text, limit: 20)
    }

    private func fetchDocument(id: UUID) -> DocumentEntity? {
        let request: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequestAll()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
}
