import SwiftUI

struct VaultView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var capture: CaptureCoordinator
    @EnvironmentObject private var navigation: AppNavigation
    @EnvironmentObject private var searchIndex: SearchIndex
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \DocumentEntity.createdAt, ascending: false)])
    private var documents: FetchedResults<DocumentEntity>

    @State private var query = ""
    @State private var selectedType: DocType?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    filterRow
                    if visibleDocuments.isEmpty {
                        emptyState
                    } else {
                        ForEach(groupedDocuments, id: \.0) { group, items in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(group)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.secondaryInk)
                                    .textCase(.uppercase)
                                ForEach(items) { document in
                                    NavigationLink(destination: DocumentDetailView(document: document)) {
                                        DocumentRow(document: document)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button("Delete", systemImage: "trash", role: .destructive) {
                                            document.purge(in: context)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .cabinetScreen()
            .navigationTitle("Vault")
            .searchable(text: $query, prompt: "Search issuers, plates, amounts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CaptureMenu(capture: capture, includeSample: documents.isEmpty)
                }
            }
        }
    }

    private var filterRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(title: "All", selected: navigation.vaultDomain == nil) {
                        navigation.vaultDomain = nil
                        selectedType = nil
                    }
                    ForEach(Domain.allCases) { domain in
                        Button {
                            navigation.vaultDomain = domain
                            selectedType = nil
                        } label: {
                            DomainChip(domain: domain, selected: navigation.vaultDomain == domain)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if !typesInScope.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(typesInScope) { type in
                            Button {
                                selectedType = selectedType == type ? nil : type
                            } label: {
                                Text(type.displayName)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(selectedType == type ? Theme.accent.opacity(0.22) : Theme.panel, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(query.isEmpty ? "This shelf is empty" : "No matches")
                .font(.title3.weight(.semibold))
            Text(query.isEmpty
                 ? "Scan or import a document and it will be classified into Car, Home, or Life."
                 : "Try a registration, issuer, or amount.")
                .foregroundStyle(Theme.secondaryInk)
        }
        .cabinetCard()
    }

    private var scopedDocuments: [DocumentEntity] {
        documents.filter { document in
            if let domain = navigation.vaultDomain, document.domainValue != domain { return false }
            if let selectedType, document.docTypeValue != selectedType { return false }
            return true
        }
    }

    private var visibleDocuments: [DocumentEntity] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return scopedDocuments }
        let matches = Set(searchIndex.topMatches(for: trimmed, limit: 40).map(\.0))
        return scopedDocuments.filter { document in
            matches.contains(document.id ?? UUID())
            || document.displayTitle.localizedCaseInsensitiveContains(trimmed)
            || document.docTypeValue.displayName.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var groupedDocuments: [(String, [DocumentEntity])] {
        let groups = Dictionary(grouping: visibleDocuments) { $0.domainValue.displayName }
        let order = Domain.allCases.map(\.displayName)
        return order.compactMap { key in
            guard let items = groups[key], !items.isEmpty else { return nil }
            return (key, items)
        }
    }

    private var typesInScope: [DocType] {
        let types = Set(scopedDocuments.map(\.docTypeValue))
        return DocType.allCases.filter { types.contains($0) }
    }

    private func filterChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(selected ? Theme.accent.opacity(0.22) : Theme.panel, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct DomainView: View {
    let domain: Domain

    var body: some View {
        VaultView()
            .onAppear {
                // Kept so older navigation paths still compile.
            }
            .navigationTitle(domain.displayName)
    }
}
