import SwiftUI

struct DomainView: View {
    @Environment(\.managedObjectContext) private var context
    let domain: Domain
    @FetchRequest private var documents: FetchedResults<DocumentEntity>

    init(domain: Domain) {
        self.domain = domain
        _documents = FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \DocumentEntity.createdAt, ascending: false)], predicate: NSPredicate(format: "domain == %@", domain.rawValue))
    }

    var body: some View {
        List {
            ForEach(documents) { document in
                NavigationLink(destination: DocumentDetailView(document: document)) {
                    DocumentRow(document: document)
                }
            }
        }
        .navigationTitle(domain.rawValue)
    }
}
