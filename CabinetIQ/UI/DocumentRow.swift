import SwiftUI

struct DocumentRow: View {
    let document: DocumentEntity

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            thumbnail
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(document.displayTitle)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    if document.dueDate != nil {
                        StatusChip(text: document.dueStatus.shortLabel, color: Theme.color(for: document.dueStatus))
                    }
                }
                Text(document.docTypeValue.displayName)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
                HStack(spacing: 8) {
                    DomainChip(domain: document.domainValue, selected: true)
                    if let amount = document.amount, let money = FieldCatalog.money(amount.decimalValue) {
                        Text(money)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.secondaryInk)
                    }
                }
            }
        }
        .cabinetCard()
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = document.thumbnailImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 54, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            Image(systemName: document.docTypeValue.icon)
                .font(.title3)
                .foregroundStyle(Theme.color(for: document.domainValue))
                .frame(width: 54, height: 68)
                .background(Theme.color(for: document.domainValue).opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}
