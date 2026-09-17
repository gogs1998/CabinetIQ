import SwiftUI

struct HomeView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var capture: CaptureCoordinator
    @EnvironmentObject private var navigation: AppNavigation
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \DocumentEntity.createdAt, ascending: false)])
    private var documents: FetchedResults<DocumentEntity>
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    if documents.isEmpty {
                        emptyState
                    } else {
                        captureStrip
                        attentionSection
                        coverageSection
                        recentSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 48)
            }
            .cabinetScreen()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    CaptureMenu(capture: capture, includeSample: documents.isEmpty)
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .onReceive(NotificationCenter.default.publisher(for: .shareImportCompleted)) { _ in
                capture.notifySuccess("Imported from Share Sheet")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(VaultInsights.greeting())
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.secondaryInk)
            Text("Cabinet")
                .font(.system(size: 36, weight: .semibold, design: .serif))
            Text(documents.isEmpty
                 ? "Your life admin, filed and remembered."
                 : attentionLine)
                .font(.body)
                .foregroundStyle(Theme.secondaryInk)
        }
        .padding(.top, 8)
    }

    private var attentionLine: String {
        let items = VaultInsights.attentionItems(in: Array(documents), limit: 1)
        if let first = items.first {
            return "\(first.displayTitle) · \(first.dueStatus.label.lowercased())."
        }
        return "Everything in date. File the next thing when it arrives."
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "cabinet.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Theme.accent)
                Text("Scan an MOT, policy, or bill.")
                    .font(.title3.weight(.semibold))
                Text("CabinetIQ reads it on this iPhone, pulls out the dates, and reminds you before they lapse. Nothing leaves the device.")
                    .foregroundStyle(Theme.secondaryInk)
            }
            .cabinetCard()

            Button {
                capture.showScanner = true
            } label: {
                Label("Scan a document", systemImage: "camera.viewfinder")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .foregroundStyle(Color.black)

            Button {
                Task { await capture.ingestSample(named: "mot_sample", context: context) }
            } label: {
                Label("See it with a sample MOT", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(Theme.ink)
        }
    }

    private var captureStrip: some View {
        HStack(spacing: 10) {
            captureButton("Scan", "camera.viewfinder") { capture.showScanner = true }
            captureButton("Photos", "photo") { capture.showPhotoPicker = true }
            captureButton("Files", "folder") { capture.showFileImporter = true }
        }
    }

    private func captureButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var attentionSection: some View {
        let items = VaultInsights.attentionItems(in: Array(documents))
        return VStack(alignment: .leading, spacing: 12) {
            sectionTitle(items.isEmpty ? "All clear" : "Needs you", accessory: items.isEmpty ? "Nothing due in 90 days" : "\(items.count)")
            if items.isEmpty {
                Text("No MOT, insurance, or bill is coming due. We’ll surface the next one here.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
                    .cabinetCard()
            } else {
                ForEach(items) { document in
                    NavigationLink(destination: DocumentDetailView(document: document)) {
                        AttentionCard(document: document)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var coverageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Coverage", accessory: "\(documents.count)")
            HStack(spacing: 10) {
                ForEach(Domain.allCases) { domain in
                    let snapshot = VaultInsights.coverage(for: domain, in: Array(documents))
                    Button {
                        navigation.openVault(domain: domain)
                    } label: {
                        CoverageCard(snapshot: snapshot)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("Recent", accessory: nil)
                Spacer()
                Button("Vault") { navigation.openVault(domain: nil) }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
            ForEach(Array(documents.prefix(5))) { document in
                NavigationLink(destination: DocumentDetailView(document: document)) {
                    DocumentRow(document: document)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func sectionTitle(_ title: String, accessory: String?) -> some View {
        HStack {
            Text(title)
                .font(.title3.weight(.semibold))
            if let accessory {
                Text(accessory)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.secondaryInk)
            }
        }
    }
}

private struct AttentionCard: View {
    let document: DocumentEntity

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: document.docTypeValue.icon)
                .font(.title3)
                .foregroundStyle(Theme.color(for: document.dueStatus))
                .frame(width: 36, height: 36)
                .background(Theme.color(for: document.dueStatus).opacity(0.16), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(document.displayTitle)
                    .font(.headline)
                Text(document.docTypeValue.displayName)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
            }
            Spacer()
            StatusChip(text: document.dueStatus.shortLabel, color: Theme.color(for: document.dueStatus))
        }
        .cabinetCard()
    }
}

private struct CoverageCard: View {
    let snapshot: CoverageSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: snapshot.domain.icon)
                .foregroundStyle(Theme.color(for: snapshot.domain))
            Text(snapshot.domain.displayName)
                .font(.headline)
            Text(snapshot.headline)
                .font(.caption)
                .foregroundStyle(Theme.secondaryInk)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cabinetCard()
    }
}

typealias InboxView = HomeView
