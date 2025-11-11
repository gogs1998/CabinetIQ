import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        Task { await handleShare() }
    }

    private func handleShare() async {
        guard let context = extensionContext else { return }
        let providers = context.inputItems.compactMap { $0 as? NSExtensionItem }
            .compactMap { $0.attachments }
            .flatMap { $0 }

        guard !providers.isEmpty else {
            context.completeRequest(returningItems: nil)
            return
        }

        guard let batchResult = await saveProviders(providers) else {
            context.completeRequest(returningItems: nil)
            return
        }

        SharedImportQueue.recordBatch(id: batchResult.id, fileNames: batchResult.fileNames)
        openHostApp(batchID: batchResult.id)
        context.completeRequest(returningItems: nil)
    }

    private func saveProviders(_ providers: [NSItemProvider]) async -> (id: String, fileNames: [String])? {
        guard let container = SharedImportQueue.sharedContainerURL() else { return nil }
        let batchID = UUID().uuidString
        let folder = container.appendingPathComponent(batchID, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            return nil
        }

        var savedNames: [String] = []
        for provider in providers {
            if let name = await save(provider: provider, to: folder) {
                savedNames.append(name)
            }
        }
        guard !savedNames.isEmpty else {
            try? FileManager.default.removeItem(at: folder)
            return nil
        }
        return (id: batchID, fileNames: savedNames)
    }

    private func save(provider: NSItemProvider, to folder: URL) async -> String? {
        if provider.hasItemConforming(to: .image) {
            return await copy(provider: provider, typeIdentifier: UTType.image.identifier, to: folder)
        } else if provider.hasItemConforming(to: .pdf) {
            return await copy(provider: provider, typeIdentifier: UTType.pdf.identifier, to: folder)
        } else if provider.hasItemConforming(to: .data) {
            return await copy(provider: provider, typeIdentifier: UTType.data.identifier, to: folder)
        }
        return nil
    }

    private func copy(provider: NSItemProvider, typeIdentifier: String, to folder: URL) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
                guard let sourceURL = url else {
                    continuation.resume(returning: nil)
                    return
                }
                let filename = provider.suggestedName ?? sourceURL.lastPathComponent
                let destination = uniqueURL(for: filename, in: folder)
                do {
                    if FileManager.default.fileExists(atPath: destination.path) {
                        try FileManager.default.removeItem(at: destination)
                    }
                    try FileManager.default.copyItem(at: sourceURL, to: destination)
                    continuation.resume(returning: destination.lastPathComponent)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func uniqueURL(for filename: String, in folder: URL) -> URL {
        let original = folder.appendingPathComponent(filename)
        let ext = original.pathExtension
        var baseName = original.deletingPathExtension().lastPathComponent
        var candidate = original
        var counter = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            let suffix = "-\(counter)"
            let newName = ext.isEmpty ? baseName + suffix : baseName + suffix + ".\(ext)"
            candidate = folder.appendingPathComponent(newName)
            counter += 1
        }
        return candidate
    }

    private func openHostApp(batchID: String) {
        guard let url = URL(string: "cabinetiq://import?batch=\(batchID)") else { return }
        extensionContext?.open(url, completionHandler: nil)
    }
}
