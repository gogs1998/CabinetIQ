import Foundation

struct SharedImportBatch: Codable, Identifiable {
    let id: String
    let fileNames: [String]
    let timestamp: Date
}

enum SharedImportQueue {
    private static let appGroupID = "group.com.examples.CabinetIQ"
    private static let queueKey = "pendingShareBatches"
    private static let importsDirectoryName = "SharedImports"

    static func sharedContainerURL() -> URL? {
        guard let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else { return nil }
        let directory = base.appendingPathComponent(importsDirectoryName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    static func recordBatch(id: String, fileNames: [String]) {
        var batches = pendingBatches().filter { $0.id != id }
        let batch = SharedImportBatch(id: id, fileNames: fileNames, timestamp: Date())
        batches.append(batch)
        persist(batches)
    }

    static func pendingBatches() -> [SharedImportBatch] {
        guard let defaults = UserDefaults(suiteName: appGroupID), let data = defaults.data(forKey: queueKey) else { return [] }
        return (try? JSONDecoder().decode([SharedImportBatch].self, from: data)) ?? []
    }

    static func consumeBatches() -> [SharedImportBatch] {
        let batches = pendingBatches()
        persist([])
        return batches
    }

    static func removeBatch(id: String) {
        var batches = pendingBatches()
        batches.removeAll { $0.id == id }
        persist(batches)
    }

    static func fileURLs(for batch: SharedImportBatch) -> [URL] {
        guard let folder = folderURL(for: batch.id) else { return [] }
        return batch.fileNames.map { folder.appendingPathComponent($0) }
    }

    static func folderURL(for batchID: String) -> URL? {
        sharedContainerURL()?.appendingPathComponent(batchID, isDirectory: true)
    }

    static func removeFiles(for batch: SharedImportBatch) {
        guard let folder = folderURL(for: batch.id) else { return }
        try? FileManager.default.removeItem(at: folder)
    }

    private static func persist(_ batches: [SharedImportBatch]) {
        guard let defaults = UserDefaults(suiteName: appGroupID), let data = try? JSONEncoder().encode(batches) else { return }
        defaults.set(data, forKey: queueKey)
    }
}
