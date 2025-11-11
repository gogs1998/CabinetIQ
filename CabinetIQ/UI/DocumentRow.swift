import SwiftUI

struct DocumentRow: View {
    let document: DocumentEntity

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(document.issuer ?? "Untitled")
                    .font(.headline)
                Spacer()
                Text(document.docType ?? DocType.other.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                if let due = document.dueDate {
                    Label("Due", systemImage: "bell")
                        .labelStyle(.iconOnly)
                    Text(due, style: .date)
                        .font(.caption)
                        .padding(6)
                        .background(Color.cyan.opacity(0.2), in: RoundedRectangle(cornerRadius: 6))
                }
                if let amount = document.amount {
                    Text(amount, formatter: currencyFormatter)
                        .font(.caption)
                }
            }
        }
    }

    private var currencyFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_GB")
        return formatter
    }
}
