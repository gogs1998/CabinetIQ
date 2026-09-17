import CoreData
import PDFKit
import UIKit

extension DocumentEntity: Identifiable {
    @nonobjc class func fetchRequestAll() -> NSFetchRequest<DocumentEntity> {
        DocumentEntity.fetchRequest()
    }

    var docTypeValue: DocType {
        DocType(rawValue: docType ?? DocType.other.rawValue) ?? .other
    }

    var domainValue: Domain {
        Domain(rawValue: domain ?? Domain.life.rawValue) ?? .life
    }

    var extractedFields: ExtractedFields? {
        guard let jsonFields else { return nil }
        return try? JSONDecoder().decode(ExtractedFields.self, from: jsonFields)
    }

    var lineGeometries: [LineGeometry] {
        guard let relatedEntities else { return [] }
        return (try? JSONDecoder().decode([LineGeometry].self, from: relatedEntities)) ?? []
    }

    var displayTitle: String {
        if let issuer, !issuer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return issuer
        }
        return docTypeValue.displayName
    }

    var displaySubtitle: String {
        var parts = [docTypeValue.displayName]
        if let due = FieldCatalog.date(dueDate) {
            parts.append("Due \(due)")
        } else if let amount = FieldCatalog.money(amount?.decimalValue) {
            parts.append(amount)
        }
        return parts.joined(separator: " · ")
    }

    var dueStatus: DueStatus {
        DueStatus.from(dueDate: dueDate)
    }

    var fieldRows: [FieldRow] {
        guard let extractedFields else { return [] }
        return FieldCatalog.rows(from: extractedFields)
    }

    var thumbnailImage: UIImage? {
        guard let path = fileURL, FileManager.default.fileExists(atPath: path) else { return nil }
        if path.lowercased().hasSuffix("pdf"),
           let pdf = PDFDocument(url: URL(fileURLWithPath: path)),
           let page = pdf.page(at: 0) {
            return page.thumbnail(of: CGSize(width: 240, height: 320), for: .mediaBox)
        }
        return UIImage(contentsOfFile: path)
    }

    func apply(fields: ExtractedFields, lines: [LineGeometry] = []) {
        jsonFields = try? JSONEncoder().encode(fields)
        relatedEntities = try? JSONEncoder().encode(lines)
        issueDate = fields.issueDate
        dueDate = fields.dueDate
        if let amount = fields.amountGBP {
            self.amount = NSDecimalNumber(decimal: amount)
        }
        if let newTag = fields.policyNumber ?? fields.reference {
            addTag(newTag)
        }
        if let address = fields.address, !address.isEmpty {
            addTag(address)
        }
    }

    @MainActor
    func purge(in context: NSManagedObjectContext) {
        ReminderService.shared.cancelReminders(for: self)
        SearchIndex.shared.remove(document: self)
        if let path = fileURL, FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.removeItem(atPath: path)
        }
        context.delete(self)
        try? context.save()
    }

    private func addTag(_ value: String) {
        var array = tags as? [String] ?? []
        if !array.contains(value) {
            array.append(value)
            tags = array as NSArray
        }
    }
}
