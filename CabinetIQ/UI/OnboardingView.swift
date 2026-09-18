import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompleted: Bool
    @EnvironmentObject private var reminderService: ReminderService

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                OnboardingPage(
                    icon: "viewfinder",
                    title: "Scan it. We read every line.",
                    bodyText: "Vision OCR stays on this iPhone. MOT certificates, policies, bills, and tax letters become searchable text — not a dead PDF."
                )
                OnboardingPage(
                    icon: "text.magnifyingglass",
                    title: "Then ask your documents.",
                    bodyText: "What’s the plate? The policy number? The mortgage rate? CabinetIQ answers from the text it read, and cites the original."
                )
                OnboardingPage(
                    icon: "bell.badge.fill",
                    title: "Dates become reminders.",
                    bodyText: "When a due date is in that text, we nudge you 30 days and 7 days before. Query is the product. Reminders are what fall out of it."
                )
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            VStack(spacing: 12) {
                Button("Enable reminders") {
                    reminderService.requestAuthorization()
                }
                .buttonStyle(.bordered)
                .tint(Theme.ink)

                Button {
                    hasCompleted = true
                } label: {
                    Text("Open my cabinet")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .foregroundStyle(Color.black)
            }
            .padding(24)
        }
        .cabinetScreen()
    }
}

private struct OnboardingPage: View {
    let icon: String
    let title: String
    let bodyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(Theme.accent)
            Text(title)
                .font(.system(size: 34, weight: .semibold, design: .serif))
            Text(bodyText)
                .font(.title3)
                .foregroundStyle(Theme.secondaryInk)
            Spacer()
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
