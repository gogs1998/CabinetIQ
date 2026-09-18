import CoreData
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import VisionKit

@MainActor
final class CaptureCoordinator: ObservableObject {
    @Published var showScanner = false
    @Published var showPhotoPicker = false
    @Published var showFileImporter = false
    @Published var selection: [PhotosPickerItem] = []
    @Published var isProcessing = false
    @Published var successMessage: String?
    @Published var errorMessage: String?
    @Published var lastDocumentID: UUID?

    func handleScannedImages(_ images: [UIImage], context: NSManagedObjectContext) async {
        let cgImages = images.compactMap(\.cgImage)
        await ingest(images: cgImages, source: .scan, context: context)
    }

    func handlePhotoItems(context: NSManagedObjectContext) async {
        let cgImages: [CGImage] = await selection.asyncCompactMap { item in
            guard let data = try? await item.loadTransferable(type: Data.self) else { return nil }
            return UIImage(data: data)?.cgImage
        }
        selection.removeAll()
        await ingest(images: cgImages, source: .photos, context: context)
    }

    func handleFileURLs(_ urls: [URL], context: NSManagedObjectContext) async {
        isProcessing = true
        defer { isProcessing = false }
        for url in urls {
            do {
                let document = try await IngestPipeline.shared.ingest(fileURL: url, source: .files, context: context)
                lastDocumentID = document.id
                notifySuccess(VaultInsights.ingestSummary(for: document))
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func ingestSample(named name: String, context: NSManagedObjectContext) async {
        guard let text = BundledSamples.text(named: name) else {
            errorMessage = "Sample \(name) is missing from the app bundle."
            return
        }
        do {
            isProcessing = true
            defer { isProcessing = false }
            let document = try await IngestPipeline.shared.ingest(text: text, source: .sample, context: context)
            lastDocumentID = document.id
            notifySuccess(VaultInsights.ingestSummary(for: document))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func ingest(images: [CGImage], source: DocumentSource, context: NSManagedObjectContext) async {
        guard !images.isEmpty else { return }
        isProcessing = true
        defer { isProcessing = false }
        do {
            let document = try await IngestPipeline.shared.ingest(images: images, source: source, context: context)
            lastDocumentID = document.id
            notifySuccess(VaultInsights.ingestSummary(for: document))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func notifySuccess(_ message: String) {
        successMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if self.successMessage == message {
                self.successMessage = nil
            }
        }
    }
}

struct CaptureOverlays: ViewModifier {
    @ObservedObject var capture: CaptureCoordinator
    @Environment(\.managedObjectContext) private var context

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $capture.showScanner) {
                DocumentScannerView { images in
                    Task { await capture.handleScannedImages(images, context: context) }
                    capture.showScanner = false
                } onCancel: {
                    capture.showScanner = false
                }
            }
            .photosPicker(isPresented: $capture.showPhotoPicker, selection: $capture.selection, maxSelectionCount: 10, matching: .images)
            .fileImporter(isPresented: $capture.showFileImporter, allowedContentTypes: [.pdf, .image], allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls):
                    Task { await capture.handleFileURLs(urls, context: context) }
                case .failure(let error):
                    capture.errorMessage = error.localizedDescription
                }
            }
            .task(id: capture.selection) {
                guard !capture.selection.isEmpty else { return }
                await capture.handlePhotoItems(context: context)
            }
            .overlay(alignment: .bottom) {
                VStack(spacing: 8) {
                    if let message = capture.successMessage {
                        Label(message, systemImage: "checkmark.circle.fill")
                            .font(.footnote.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    if capture.isProcessing {
                        ProgressView("Reading on this iPhone…")
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(.thinMaterial, in: Capsule())
                    }
                }
                .padding()
            }
            .alert("Import failed", isPresented: Binding(get: { capture.errorMessage != nil }, set: { _ in capture.errorMessage = nil })) {
                Button("Dismiss", role: .cancel) {}
            } message: {
                Text(capture.errorMessage ?? "")
            }
    }
}

struct CaptureMenu: View {
    @ObservedObject var capture: CaptureCoordinator
    @Environment(\.managedObjectContext) private var context
    var includeSample: Bool = false

    var body: some View {
        Menu {
            Button("Scan", systemImage: "camera.viewfinder") { capture.showScanner = true }
            Button("Photos", systemImage: "photo") { capture.showPhotoPicker = true }
            Button("Files", systemImage: "folder") { capture.showFileImporter = true }
            if includeSample {
                Button("Try a sample MOT", systemImage: "sparkles") {
                    Task { await capture.ingestSample(named: "mot_sample", context: context) }
                }
            }
        } label: {
            Label("Add", systemImage: "plus.circle.fill")
        }
    }
}

struct DocumentScannerView: UIViewControllerRepresentable {
    var onFinish: ([UIImage]) -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScannerView
        init(parent: DocumentScannerView) { self.parent = parent }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            for index in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: index))
            }
            parent.onFinish(images)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.onCancel()
        }
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
