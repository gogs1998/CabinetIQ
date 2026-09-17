import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompleted: Bool
    @EnvironmentObject private var reminderService: ReminderService

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                OnboardingPage(
                    icon: "cabinet.fill",
                    title: "A cabinet for real life",
                    bodyText: "MOT certificates, insurance, mortgages, bills, and tax letters — filed into Car, Home, and Life."
                )
                OnboardingPage(
                    icon: "viewfinder",
                    title: "Scan once. We read it.",
                    bodyText: "Vision OCR stays on this iPhone. We pull out dates, amounts, plates, and policy numbers so you don’t have to retype them."
                )
                OnboardingPage(
                    icon: "bell.badge.fill",
                    title: "Never miss a renewal",
                    bodyText: "When a due date is found, CabinetIQ reminds you 30 days and 7 days before. Ask the cabinet in plain English anytime."
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
