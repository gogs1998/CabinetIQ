import AppIntents

struct AskCabinetIQIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask CabinetIQ"
    static var description = IntentDescription("Get a quick answer from your CabinetIQ vault.")

    @Parameter(title: "Question", default: "When is my MOT due?")
    var question: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = PersistenceController.shared.container.viewContext
        if let deterministic = IntentShortcuts.answer(query: question, context: context) {
            return .result(dialog: IntentDialog(deterministic.text))
        }
        let ragAnswer = await RAGEngine.shared.answer(question: question, scope: .all, context: context)
        return .result(dialog: IntentDialog(ragAnswer.text))
    }
}
