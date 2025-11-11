import SwiftUI

struct RootTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            InboxView()
                .tabItem { Label("Home", systemImage: "tray.full") }
                .tag(0)

            NavigationStack { DomainView(domain: .car) }
                .tabItem { Label("Car", systemImage: "car.fill") }
                .tag(1)

            NavigationStack { DomainView(domain: .home) }
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(2)

            NavigationStack { DomainView(domain: .life) }
                .tabItem { Label("Life", systemImage: "heart.text.square") }
                .tag(3)

            AskView()
                .tabItem { Label("Ask", systemImage: "questionmark.bubble") }
                .tag(4)
        }
        .tint(Theme.accent)
    }
}
