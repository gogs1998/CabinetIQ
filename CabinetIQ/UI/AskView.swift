import SwiftUI
import CoreData

struct AskView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var rag: RAGEngine
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \DocumentEntity.createdAt, ascending: false)])
    private var documents: FetchedResults<DocumentEntity>

    @State private var turns: [AskTurn] = []
    @State private var input = ""
    @State private var scope: AskScope = .all
    @State private var isThinking = false
    @State private var selectedDocumentID: UUID?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                scopePicker
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if turns.isEmpty {
                                emptyState
                            }
                            ForEach(turns) { turn in
                                turnView(turn)
                                    .id(turn.id)
                            }
                            if isThinking {
                                ProgressView("Looking through your cabinet…")
                                    .tint(Theme.accent)
                            }
                        }
                        .padding(20)
                    }
                    .onChange(of: turns.count) { _, _ in
                        if let last = turns.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
                askBar
            }
            .cabinetScreen()
            .navigationTitle("Ask")
            .sheet(item: $selectedDocumentID) { id in
                if let document = fetchDocument(id: id) {
                    NavigationStack {
                        DocumentDetailView(document: document)
                    }
                } else {
                    Text("That document is no longer in the cabinet.")
                        .padding()
                }
            }
        }
    }

    private var scopePicker: some View {
        Menu {
            Button("All documents") { scope = .all }
            Section("Cabinets") {
                ForEach(Domain.allCases) { domain in
                    Button(domain.displayName) { scope = .domain(domain) }
                }
            }
            Section("Types") {
                ForEach(DocType.allCases) { type in
                    Button(type.displayName) { scope = .docType(type) }
                }
            }
        } label: {
            Label(scope.label, systemImage: "line.3.horizontal.decrease.circle")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.panel, in: Capsule())
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ask your cabinet")
                .font(.system(size: 28, weight: .semibold, design: .serif))
            Text("Answers stay on this iPhone. Start with a question we can already answer from what you’ve filed.")
                .foregroundStyle(Theme.secondaryInk)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(VaultInsights.suggestedQuestions(for: Array(documents)), id: \.self) { question in
                    Button {
                        input = question
                        send()
                    } label: {
                        Text(question)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.panel, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var askBar: some View {
        HStack(spacing: 10) {
            TextField("Ask about MOT, bills, tax…", text: $input, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(canSend ? Theme.accent : Theme.secondaryInk)
            }
            .disabled(!canSend)
        }
        .padding(16)
        .background(Theme.background)
    }

    private var canSend: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isThinking
    }

    private func turnView(_ turn: AskTurn) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(turn.question)
                .padding(12)
                .background(Theme.panelElevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .frame(maxWidth: .infinity, alignment: .trailing)
            VStack(alignment: .leading, spacing: 8) {
                Text(turn.answer.source == .rag ? "From your documents" : "From a known fact")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.secondaryInk)
                Text(turn.answer.text)
                if !turn.answer.citations.isEmpty {
                    ForEach(turn.answer.citations) { citation in
                        Button {
                            selectedDocumentID = citation.documentID
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                highlightedText(for: citation.snippet, tokens: tokens(from: turn.question))
                                    .font(.caption)
                                    .multilineTextAlignment(.leading)
                                Text("Open document")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Theme.accent)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(14)
            .background(Theme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func send() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        input = ""
        isThinking = true
        Task {
            let answer: AskAnswer
            if let intent = IntentShortcuts.answer(query: trimmed, context: context) {
                answer = intent
            } else {
                answer = await rag.answer(question: trimmed, scope: scope, context: context)
            }
            turns.append(AskTurn(question: trimmed, answer: answer))
            isThinking = false
        }
    }

    private func highlightedText(for snippet: String, tokens: [String]) -> Text {
        var attributed = AttributedString(snippet)
        for token in tokens where token.count > 2 {
            highlight(token: token, in: snippet, attributed: &attributed)
        }
        return Text(attributed)
    }

    private func highlight(token: String, in snippet: String, attributed: inout AttributedString) {
        let nsSnippet = snippet as NSString
        var searchRange = NSRange(location: 0, length: nsSnippet.length)
        while true {
            let range = nsSnippet.range(of: token, options: [.caseInsensitive], range: searchRange)
            if range.location == NSNotFound { break }
            if let swiftRange = Range(range, in: snippet),
               let attrStart = AttributedString.Index(swiftRange.lowerBound, within: attributed),
               let attrEnd = AttributedString.Index(swiftRange.upperBound, within: attributed) {
                attributed[attrStart..<attrEnd].foregroundColor = Theme.accent
                attributed[attrStart..<attrEnd].font = .caption.bold()
            }
            let nextLocation = range.location + range.length
            if nextLocation >= nsSnippet.length { break }
            searchRange = NSRange(location: nextLocation, length: nsSnippet.length - nextLocation)
        }
    }

    private func tokens(from question: String) -> [String] {
        question
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count > 2 }
            .uniqued()
    }

    private func fetchDocument(id: UUID) -> DocumentEntity? {
        let request: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequestAll()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
}

private struct AskTurn: Identifiable {
    let id = UUID()
    let question: String
    let answer: AskAnswer
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var set: Set<Element> = []
        return filter { set.insert($0).inserted }
    }
}

extension UUID: Identifiable {
    public var id: UUID { self }
}
