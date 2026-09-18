import SwiftUI

enum Theme {
    static let accent = Color(red: 0.86, green: 0.68, blue: 0.42)
    static let background = Color(red: 0.07, green: 0.065, blue: 0.055)
    static let panel = Color(red: 0.13, green: 0.12, blue: 0.10)
    static let panelElevated = Color(red: 0.17, green: 0.155, blue: 0.13)
    static let ink = Color(red: 0.97, green: 0.94, blue: 0.88)
    static let secondaryInk = Color(red: 0.74, green: 0.70, blue: 0.63)
    static let stroke = Color.white.opacity(0.07)
    static let overdue = Color(red: 0.93, green: 0.43, blue: 0.36)
    static let soon = Color(red: 0.95, green: 0.72, blue: 0.32)
    static let ok = Color(red: 0.52, green: 0.74, blue: 0.54)

    static let car = Color(red: 0.50, green: 0.72, blue: 0.88)
    static let home = Color(red: 0.74, green: 0.60, blue: 0.88)
    static let life = Color(red: 0.90, green: 0.58, blue: 0.50)

    static func color(for domain: Domain) -> Color {
        switch domain {
        case .car: return car
        case .home: return home
        case .life: return life
        }
    }

    static func color(for status: DueStatus) -> Color {
        switch status {
        case .overdue: return overdue
        case .dueSoon: return soon
        case .upcoming: return accent
        case .clear: return ok
        case .none: return secondaryInk
        }
    }
}

extension View {
    func cabinetScreen() -> some View {
        self
            .foregroundStyle(Theme.ink)
            .background(Theme.background.ignoresSafeArea())
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }

    func cabinetCard() -> some View {
        self
            .padding(16)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Theme.stroke, lineWidth: 1)
            )
    }
}

struct StatusChip: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color.opacity(0.16), in: Capsule())
    }
}

struct DomainChip: View {
    let domain: Domain
    var selected: Bool = true

    var body: some View {
        Label(domain.displayName, systemImage: domain.icon)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(selected ? Theme.ink : Theme.secondaryInk)
            .background(
                (selected ? Theme.color(for: domain).opacity(0.22) : Theme.panel),
                in: Capsule()
            )
    }
}
