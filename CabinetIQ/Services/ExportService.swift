import SwiftUI

final class ExportService: ObservableObject {
    static let shared = ExportService()

    func bundle(for document: DocumentEntity) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("CabinetIQExport_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let path = document.fileURL {
            let src = URL(fileURLWithPath: path)
            let dst = directory.appendingPathComponent(src.lastPathComponent)
            if FileManager.default.fileExists(atPath: dst.path) {
                try FileManager.default.removeItem(at: dst)
            }
            if FileManager.default.fileExists(atPath: src.path) {
                try FileManager.default.copyItem(at: src, to: dst)
            }
        }
        if let data = document.jsonFields {
            let url = directory.appendingPathComponent("extracted.json")
            try data.write(to: url)
        }
        return directory
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
