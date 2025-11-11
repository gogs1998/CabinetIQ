import CoreData

@MainActor
final class ShareImportHandler {
    static let shared = ShareImportHandler()

    func processPendingImports(context: NSManagedObjectContext) async {
        let batches = SharedImportQueue.consumeBatches()
        guard !batches.isEmpty else { return }
        var hadSuccess = false
        for batch in batches {
            let urls = SharedImportQueue.fileURLs(for: batch)
            var succeeded = true
            for url in urls {
                do {
                    try await IngestPipeline.shared.ingest(fileURL: url, source: .share, context: context)
                } catch {
                    succeeded = false
                }
            }
            if succeeded {
                SharedImportQueue.removeFiles(for: batch)
                hadSuccess = true
            } else {
                SharedImportQueue.recordBatch(id: batch.id, fileNames: batch.fileNames)
            }
        }
        if hadSuccess {
            NotificationCenter.default.post(name: .shareImportCompleted, object: nil)
        }
    }
}

extension Notification.Name {
    static let shareImportCompleted = Notification.Name("ShareImportCompletedNotification")
}
