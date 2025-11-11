import CoreData

extension DocumentEntity {
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

    private func addTag(_ value: String) {
        var array = tags as? [String] ?? []
        if !array.contains(value) {
            array.append(value)
            tags = array as NSArray
        }
    }
}
