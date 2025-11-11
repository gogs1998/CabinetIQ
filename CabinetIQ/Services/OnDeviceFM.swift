import Foundation

protocol OnDeviceFoundationModeling {
    func answer(question: String, context: String) async throws -> String
    func extractJSON(for type: DocType, from text: String) async throws -> Data
}

struct OnDeviceFM: OnDeviceFoundationModeling {
    func answer(question: String, context: String) async throws -> String {
        // Placeholder – integrate with Apple's On-Device FM / PCC when available
        return "(FM disabled) \(context.prefix(280))"
    }

    func extractJSON(for type: DocType, from text: String) async throws -> Data {
        Data() // placeholder – call Foundation Model later
    }
}
