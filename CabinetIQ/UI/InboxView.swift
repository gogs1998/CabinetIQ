import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct InboxView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \DocumentEntity.createdAt, ascending: false)])
    private var documents: FetchedResults<DocumentEntity>

    @State private var showScanner = false
    @State private var showPhotoPicker = false
    @State private var showFileImporter = false
    @State private var showSettings = false
    @State private var selection: [PhotosPickerItem] = []
    @State private var isProcessing = false
    @State private var successMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if documents.isEmpty {
                    ContentUnavailableView("No documents", systemImage: "tray", description: Text("Scan or import to get started."))
                }
                if !upcomingDocuments.isEmpty {
                    Section("Upcoming renewals") {
                        ForEach(upcomingDocuments) { document in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(document.issuer ?? document.docType ?? "Document")
                                        .font(.subheadline.weight(.medium))
                                    if let due = document.dueDate {
                                        Text(due, style: .date)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "bell.badge")
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
                ForEach(documents) { document in
                    NavigationLink(destination: DocumentDetailView(document: document)) {
                        DocumentRow(document: document)
                    }
                }
            }
            .navigationTitle("Inbox")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Scan", systemImage: "camera.viewfinder") { showScanner = true }
                        Button("Photos", systemImage: "photo") { showPhotoPicker = true }
                        Button("Files", systemImage: "folder") { showFileImporter = true }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .overlay(alignment: .bottom) {
                VStack(spacing: 8) {
                    if let message = successMessage {
                        Label(message, systemImage: "checkmark.circle.fill")
                            .padding(12)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    if isProcessing {
                        ProgressView("Processing…")
                            .padding(12)
                            .background(.thinMaterial, in: Capsule())
                    }
                }
                .padding()
            }
            .alert("Import failed", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
                Button("Dismiss", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(isPresented: $showScanner) {
                DocumentScannerView { images in
                    Task { await handleScannedImages(images) }
                    showScanner = false
                } onCancel: {
                    showScanner = false
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $selection, maxSelectionCount: 10, matching: .images)
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.pdf, .image], allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls):
                    Task { await handleFileURLs(urls) }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
            .task(id: selection) {
                guard !selection.isEmpty else { return }
                await handlePhotoItems()
            }
            .onReceive(NotificationCenter.default.publisher(for: .shareImportCompleted)) { _ in
                notifySuccess("Imported from Share Sheet")
            }
        }
    }

    private func handleScannedImages(_ images: [UIImage]) async {
        let cgImages = images.compactMap { $0.cgImage }
        await ingest(images: cgImages, source: .scan)
    }

    private func handlePhotoItems() async {
        let cgImages: [CGImage] = await selection.asyncCompactMap { item in
            guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data)?.cgImage else { return nil }
            return image
        }
        selection.removeAll()
        await ingest(images: cgImages, source: .photos)
    }

    private func handleFileURLs(_ urls: [URL]) async {
        isProcessing = true
        defer { isProcessing = false }
        for url in urls {
            do {
                try await IngestPipeline.shared.ingest(fileURL: url, source: .files, context: context)
                notifySuccess("Imported \(url.lastPathComponent)")
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func ingest(images: [CGImage], source: DocumentSource) async {
        guard !images.isEmpty else { return }
        isProcessing = true
        defer { isProcessing = false }
        do {
            try await IngestPipeline.shared.ingest(images: images, source: source, context: context)
            notifySuccess("Document added")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func notifySuccess(_ message: String) {
        successMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if successMessage == message {
                successMessage = nil
            }
        }
    }

    private var upcomingDocuments: [DocumentEntity] {
        let now = Date()
        let future = Calendar.current.date(byAdding: .day, value: 60, to: now) ?? now
        return documents
            .filter { document in
                guard let due = document.dueDate else { return false }
                return due >= now && due <= future
            }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
            .prefix(3)
            .map { $0 }
    }
}

private extension Array where Element == PhotosPickerItem {
    func asyncCompactMap<T>(_ transform: @escaping (Element) async -> T?) async -> [T] {
        var values: [T] = []
        for element in self {
            if let value = await transform(element) {
                values.append(value)
            }
        }
        return values
    }
}
