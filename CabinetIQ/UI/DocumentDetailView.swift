import SwiftUI
import QuickLook

struct DocumentDetailView: View {
    @ObservedObject var document: DocumentEntity
    @State private var exportURL: URL?
    @State private var showShareSheet = false
    @State private var previewURL: URL?
    @EnvironmentObject private var reminderService: ReminderService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                fieldSection
                reminderSection
                ocrSection
            }
            .padding()
        }
        .navigationTitle(document.issuer ?? "Document")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: export) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let exportURL {
                ShareSheet(items: [exportURL])
            }
        }
        .quickLookPreview($previewURL)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(document.docType ?? DocType.other.rawValue)
                .font(.title.weight(.semibold))
            if let issue = document.issueDate {
                Label("Issued \(issue.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar")
            }
            if let due = document.dueDate {
                Label("Due \(due.formatted(date: .abbreviated, time: .omitted))", systemImage: "bell")
            }
            if let amount = document.amount {
                Text(amount, formatter: currencyFormatter)
                    .font(.title3)
            }
        }
    }

    private var fieldSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Extracted Fields").font(.headline)
            if let json = document.jsonFields, let string = String(data: json, encoding: .utf8) {
                Text(string)
                    .font(.system(.footnote, design: .monospaced))
                    .padding()
                    .background(Theme.panel, in: RoundedRectangle(cornerRadius: 12))
            } else {
                Text("No structured data yet.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reminders").font(.headline)
            if document.dueDate != nil {
                if reminderService.isAuthorized {
                    Text("Scheduled at −30d and −7d at 09:00")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Enable notifications to schedule reminders")
                        .foregroundStyle(.red)
                }
            } else {
                Text("No due date detected").foregroundStyle(.secondary)
            }
        }
    }

    private var ocrSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OCR Text").font(.headline)
            Text(document.ocrText ?? "")
                .font(.footnote)
            if document.fileURL != nil {
                Button("Open Original", action: openOriginal)
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private func export() {
        do {
            exportURL = try ExportService.shared.bundle(for: document)
            showShareSheet = true
        } catch {
            // TODO: surface error to user via alert if needed
        }
    }

    private func openOriginal() {
        guard let path = document.fileURL, FileManager.default.fileExists(atPath: path) else { return }
        previewURL = URL(fileURLWithPath: path)
    }

    private var currencyFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_GB")
        return formatter
    }
}
