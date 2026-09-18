import CoreData
import Foundation
import PDFKit
import SwiftUI
import UIKit
import Vision
import VisionKit

@MainActor
final class IngestPipeline: ObservableObject {
    static let shared = IngestPipeline()

    private let classifier = DocumentClassifier()
    private let extractor = FieldExtractor.shared

    @discardableResult
    func ingest(images: [CGImage], source: DocumentSource, context: NSManagedObjectContext) async throws -> DocumentEntity {
        let (text, lines) = try await performOCR(on: images)
        let data = images.first.flatMap { UIImage(cgImage: $0).jpegData(compressionQuality: 0.9) }
        let url = try data.flatMap { try persist(data: $0, suggestedExtension: "jpg") }
        return try await persistDocument(text: text, lines: lines, fileURL: url, source: source, context: context)
    }

    @discardableResult
    func ingest(fileURL: URL, source: DocumentSource, context: NSManagedObjectContext) async throws -> DocumentEntity {
        let cgImage: CGImage
        if fileURL.pathExtension.lowercased() == "pdf", let pdf = PDFDocument(url: fileURL), let page = pdf.page(at: 0) {
            cgImage = page.thumbnail(of: CGSize(width: 1200, height: 1200), for: .mediaBox).cgImage!
        } else if let image = UIImage(contentsOfFile: fileURL.path)?.cgImage {
            cgImage = image
        } else {
            throw NSError(domain: "CabinetIQ", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unsupported file"])
        }
        let (text, lines) = try await performOCR(on: [cgImage])
        let stored = try persistExisting(fileURL: fileURL)
        return try await persistDocument(text: text, lines: lines, fileURL: stored, source: source, context: context)
    }

    @discardableResult
    func ingest(text: String, source: DocumentSource, context: NSManagedObjectContext) async throws -> DocumentEntity {
        try await persistDocument(text: text, lines: [], fileURL: nil, source: source, context: context)
    }

    private func performOCR(on images: [CGImage]) async throws -> (String, [LineGeometry]) {
        var aggregated = ""
        var lines: [LineGeometry] = []
        for image in images {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-GB"]
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try handler.perform([request])
            for observation in request.results ?? [] {
                let text = observation.topCandidates(1).first?.string ?? ""
                aggregated += text + "\n"
                lines.append(LineGeometry(text: text, boundingBox: observation.boundingBox))
            }
        }
        return (aggregated.trimmingCharacters(in: .whitespacesAndNewlines), lines)
    }

    @discardableResult
    private func persistDocument(text: String, lines: [LineGeometry], fileURL: URL?, source: DocumentSource, context: NSManagedObjectContext) async throws -> DocumentEntity {
        let (domain, docType, issuer) = classifier.classify(text: text)
        let document = DocumentEntity(context: context)
        document.id = UUID()
        document.createdAt = Date()
        document.source = source.rawValue
        document.issuer = issuer
        document.domain = domain.rawValue
        document.docType = docType.rawValue
        document.fileURL = fileURL?.path
        document.ocrText = text

        let fields = await extractor.extract(for: docType, text: text)
        document.apply(fields: fields, lines: lines)
        try context.save()
        if document.dueDate != nil {
            ReminderService.shared.scheduleReminders(for: document)
        }
        SearchIndex.shared.index(document: document)
        return document
    }

    private func persist(data: Data, suggestedExtension: String) throws -> URL {
        let directory = try documentsDirectory()
        let url = directory.appendingPathComponent("\(UUID().uuidString).\(suggestedExtension)")
        try data.write(to: url)
        return url
    }

    private func persistExisting(fileURL: URL) throws -> URL {
        let directory = try documentsDirectory()
        let destination = directory.appendingPathComponent(fileURL.lastPathComponent)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: fileURL, to: destination)
        return destination
    }

    private func documentsDirectory() throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = base.appendingPathComponent("CabinetIQ", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }
}
