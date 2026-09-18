import SwiftUI
import QuickLook

struct DocumentDetailView: View {
    @ObservedObject var document: DocumentEntity
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var reminderService: ReminderService
    @EnvironmentObject private var navigation: AppNavigation

    @State private var exportURL: URL?
    @State private var showShareSheet = false
    @State private var previewURL: URL?
    @State private var showEditor = false
    @State private var showDeleteConfirm = false
    @State private var exportError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if document.dueDate != nil {
                    StatusChip(text: document.dueStatus.label, color: Theme.color(for: document.dueStatus))
                }
                preview
                askButton
                fieldSection
                reminderSection
                ocrSection
                Button("Delete document", role: .destructive) {
                    showDeleteConfirm = true
                }
                .frame(maxWidth: .infinity)
            }
            .padding(20)
        }
        .cabinetScreen()
        .navigationTitle(document.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Edit details", systemImage: "pencil") { showEditor = true }
                    Button("Export", systemImage: "square.and.arrow.up", action: export)
                    if document.fileURL != nil {
                        Button("Open original", systemImage: "doc.richtext", action: openOriginal)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let exportURL {
                ShareSheet(items: [exportURL])
            }
        }
        .sheet(isPresented: $showEditor) {
            DocumentEditorView(document: document)
        }
        .quickLookPreview($previewURL)
        .alert("Couldn’t export", isPresented: Binding(get: { exportError != nil }, set: { _ in exportError = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
        .confirmationDialog("Delete this document?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                document.purge(in: context)
                dismiss()
            }
        } message: {
            Text("The original file and reminders will be removed from this iPhone.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(document.docTypeValue.displayName)
                .font(.system(size: 28, weight: .semibold, design: .serif))
            HStack(spacing: 8) {
                DomainChip(domain: document.domainValue)
                if let amount = document.amount, let money = FieldCatalog.money(amount.decimalValue) {
                    Text(money)
                        .font(.title3.weight(.semibold))
                }
            }
            if let issued = FieldCatalog.date(document.issueDate) {
                Label("Issued \(issued)", systemImage: "calendar")
                    .foregroundStyle(Theme.secondaryInk)
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let image = document.thumbnailImage {
            Button(action: openOriginal) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var fieldSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key facts")
                .font(.headline)
            if document.fieldRows.isEmpty {
                Text("No structured fields yet. You can add a due date so reminders still work.")
                    .foregroundStyle(Theme.secondaryInk)
                    .cabinetCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(document.fieldRows) { row in
                        HStack(alignment: .top) {
                            Text(row.label)
                                .foregroundStyle(Theme.secondaryInk)
                                .frame(width: 130, alignment: .leading)
                            Text(row.value)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .font(.subheadline)
                        .padding(.vertical, 10)
                        if row.id != document.fieldRows.last?.id {
                            Divider().overlay(Theme.stroke)
                        }
                    }
                }
                .cabinetCard()
            }
        }
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Reminders")
                .font(.headline)
            if document.dueDate != nil {
                if reminderService.isAuthorized {
                    Text("We’ll nudge you 30 days and 7 days before the due date, at 9:00.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryInk)
                } else {
                    Text("Turn on notifications so MOT, insurance, and bills don’t lapse.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.soon)
                    Button("Enable reminders") {
                        reminderService.requestAuthorization()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .foregroundStyle(Color.black)
                }
            } else {
                Text("No due date yet. Edit this document to add one.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
            }
        }
        .cabinetCard()
    }

    private var askButton: some View {
        Button(action: askAboutDocument) {
            Label("Ask about this document", systemImage: "text.magnifyingglass")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.accent)
        .foregroundStyle(Color.black)
    }

    private var ocrSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What we read")
                .font(.headline)
            Text(document.ocrLineCount == 0
                 ? "No text was captured."
                 : "\(document.ocrLineCount) lines stayed on this iPhone. Ask can search every one.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryInk)
            if !document.ocrPreview.isEmpty {
                Text(document.ocrPreview)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryInk)
            }
            if let text = document.ocrText, !text.isEmpty {
                DisclosureGroup("Full text") {
                    Text(text)
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryInk)
                        .padding(.top, 8)
                }
                .tint(Theme.accent)
            }
            if document.fileURL != nil {
                Button("Open original", action: openOriginal)
                    .buttonStyle(.bordered)
                    .tint(Theme.ink)
            }
        }
        .cabinetCard()
    }

    private func askAboutDocument() {
        guard let id = document.id else { return }
        let question = VaultInsights.suggestedQuestions(for: [document]).first
            ?? "What did we read on this \(document.docTypeValue.displayName)?"
        navigation.openAsk(question: question, scope: .document(id))
    }

    private func export() {
        do {
            exportURL = try ExportService.shared.bundle(for: document)
            showShareSheet = true
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func openOriginal() {
        guard let path = document.fileURL, FileManager.default.fileExists(atPath: path) else { return }
        previewURL = URL(fileURLWithPath: path)
    }
}

struct DocumentEditorView: View {
    @ObservedObject var document: DocumentEntity
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var reminderService: ReminderService

    @State private var issuer: String = ""
    @State private var domain: Domain = .life
    @State private var docType: DocType = .other
    @State private var dueDate: Date = Date()
    @State private var hasDueDate = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Issuer", text: $issuer)
                    Picker("Cabinet", selection: $domain) {
                        ForEach(Domain.allCases) { value in
                            Text(value.displayName).tag(value)
                        }
                    }
                    Picker("Type", selection: $docType) {
                        ForEach(DocType.allCases) { value in
                            Text(value.displayName).tag(value)
                        }
                    }
                }
                Section("Dates") {
                    Toggle("Has a due date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Edit document")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
            .onAppear {
                issuer = document.issuer ?? ""
                domain = document.domainValue
                docType = document.docTypeValue
                if let existing = document.dueDate {
                    dueDate = existing
                    hasDueDate = true
                }
            }
        }
    }

    private func save() {
        document.issuer = issuer.trimmingCharacters(in: .whitespacesAndNewlines)
        document.domain = domain.rawValue
        document.docType = docType.rawValue
        document.dueDate = hasDueDate ? dueDate : nil
        if var fields = document.extractedFields {
            fields.dueDate = document.dueDate
            document.apply(fields: fields)
        }
        PersistenceController.shared.save()
        SearchIndex.shared.index(document: document)
        if document.dueDate != nil {
            reminderService.scheduleReminders(for: document)
        } else {
            reminderService.cancelReminders(for: document)
        }
        dismiss()
    }
}
