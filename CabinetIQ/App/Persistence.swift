import CoreData

final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Entities")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Unresolved error: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func save(context: NSManagedObjectContext? = nil) {
        let context = context ?? container.viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            assertionFailure("Failed to save context: \(error)")
        }
    }

    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        for idx in 0..<3 {
            let doc = DocumentEntity(context: context)
            doc.id = UUID()
            doc.createdAt = Date().addingTimeInterval(Double(idx) * -86400)
            doc.source = DocumentSource.scan.rawValue
            doc.issuer = "Preview Issuer"
            doc.domain = Domain.car.rawValue
            doc.docType = DocType.mot.rawValue
            doc.ocrText = "Preview OCR text"
            doc.fileURL = ""
            doc.jsonFields = try? JSONEncoder().encode(ExtractedFields())
        }
        try? context.save()
        return controller
    }()
}
