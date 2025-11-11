import SwiftUI
import CoreData

struct AskView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var rag: RAGEngine
    @State private var messages: [AskAnswer] = []
    @State private var input = ""
    @State private var scope: AskScope = .all
    @State private var isThinking = false
    @State private var selectedDocumentID: UUID?

    var body: some View {
        NavigationStack {
            VStack {
                scopePicker
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(messages) { message in
                                messageBubble(for: message)
                            }
                            if isThinking {
                                ProgressView("Thinking…")
                            }
                        }
                        .padding()
                    }
                }
                askBar
            }
            .navigationTitle("Ask CabinetIQ")
            .sheet(item: $selectedDocumentID) { id in
                if let document = fetchDocument(id: id) {
                    NavigationStack {
                        DocumentDetailView(document: document)
                    }
                } else {
                    Text("Document no longer exists.")
                        .padding()
                }
            }
        }
    }

    private var scopePicker: some View {
        Menu {
            Button("All Documents") { scope = .all }
            Section("Domains") {
                ForEach(Domain.allCases) { domain in
                    Button(domain.rawValue) { scope = .domain(domain) }
                }
            }
            Section("Doc Types") {
                ForEach(DocType.allCases) { type in
                    Button(type.rawValue) { scope = .docType(type) }
                }
            }
        } label: {
            Label("Scope", systemImage: "line.3.horizontal.decrease.circle")
        }
    }

    private var askBar: some View {
        HStack {
            TextField("Ask about your docs", text: $input)
                .textFieldStyle(.roundedBorder)
            Button(action: send) {
                Image(systemName: "paperplane.fill")
            }
            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isThinking)
        }
        .padding()
    }

    private func messageBubble(for message: AskAnswer) -> some View {
        let questionTokens = tokens(from: message.question)
        VStack(alignment: .leading, spacing: 6) {
            Text(message.source == .rag ? "RAG" : "Intent")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(message.text)
                .padding()
                .background(message.source == .rag ? Color.cyan.opacity(0.2) : Color.gray.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
            if !message.citations.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(message.citations) { citation in
                        Button {
                            selectedDocumentID = citation.documentID
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                highlightedText(for: citation.snippet, tokens: questionTokens)
                                    .font(.caption)
                                    .multilineTextAlignment(.leading)
                                Text("Open document")
                                    .font(.caption2)
                                    .foregroundStyle(.cyan)
                            }
                            .padding(10)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func send() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        input = ""
        isThinking = true
        Task {
            if let intent = IntentShortcuts.answer(query: trimmed, context: context) {
                messages.append(intent)
            } else {
                let answer = await rag.answer(question: trimmed, scope: scope, context: context)
                messages.append(answer)
            }
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
                attributed[attrStart..<attrEnd].foregroundColor = .cyan
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

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var set: Set<Element> = []
        return filter { set.insert($0).inserted }
    }
}

extension UUID: Identifiable {
    public var id: UUID { self }
}
