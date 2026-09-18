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
        let calendar = Calendar.current

        let mot = DocumentEntity(context: context)
        mot.id = UUID()
        mot.createdAt = Date().addingTimeInterval(-86400)
        mot.source = DocumentSource.sample.rawValue
        mot.issuer = "DVSA"
        mot.domain = Domain.car.rawValue
        mot.docType = DocType.mot.rawValue
        mot.ocrText = "MOT test certificate CAB123"
        mot.dueDate = calendar.date(byAdding: .day, value: 12, to: Date())
        var motFields = ExtractedFields()
        motFields.dueDate = mot.dueDate
        var motPayload = MOTFields()
        motPayload.vrm = "CAB123"
        motPayload.expiryDate = mot.dueDate
        motFields.mot = motPayload
        mot.apply(fields: motFields)

        let insurance = DocumentEntity(context: context)
        insurance.id = UUID()
        insurance.createdAt = Date().addingTimeInterval(-172800)
        insurance.source = DocumentSource.scan.rawValue
        insurance.issuer = "Admiral"
        insurance.domain = Domain.car.rawValue
        insurance.docType = DocType.insurance.rawValue
        insurance.ocrText = "Certificate of insurance CAB123"
        insurance.dueDate = calendar.date(byAdding: .day, value: 40, to: Date())
        insurance.amount = NSDecimalNumber(value: 456.70)

        let mortgage = DocumentEntity(context: context)
        mortgage.id = UUID()
        mortgage.createdAt = Date().addingTimeInterval(-259200)
        mortgage.source = DocumentSource.files.rawValue
        mortgage.issuer = "Nationwide"
        mortgage.domain = Domain.home.rawValue
        mortgage.docType = DocType.mortgage.rawValue
        mortgage.ocrText = "Fixed rate 4.29%"
        var mortgageFields = ExtractedFields()
        var mortgagePayload = MortgageFields()
        mortgagePayload.lender = "Nationwide"
        mortgagePayload.rate = 4.29
        mortgagePayload.fixEnd = calendar.date(byAdding: .day, value: 200, to: Date())
        mortgageFields.mortgage = mortgagePayload
        mortgage.apply(fields: mortgageFields)

        try? context.save()
        return controller
    }()
}
