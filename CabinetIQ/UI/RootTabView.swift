import SwiftUI

@MainActor
final class AppNavigation: ObservableObject {
    @Published var selectedTab = 0
    @Published var vaultDomain: Domain?

    func openVault(domain: Domain?) {
        vaultDomain = domain
        selectedTab = 1
    }
}

struct RootTabView: View {
    @StateObject private var navigation = AppNavigation()
    @StateObject private var capture = CaptureCoordinator()

    var body: some View {
        TabView(selection: $navigation.selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "square.grid.2x2.fill") }
                .tag(0)

            VaultView()
                .tabItem { Label("Vault", systemImage: "cabinet.fill") }
                .tag(1)

            AskView()
                .tabItem { Label("Ask", systemImage: "text.bubble.fill") }
                .tag(2)
        }
        .tint(Theme.accent)
        .environmentObject(navigation)
        .environmentObject(capture)
        .modifier(CaptureOverlays(capture: capture))
        .toolbarBackground(Theme.background, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
    }
}
