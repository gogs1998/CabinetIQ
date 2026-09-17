import SwiftUI
import CoreData

@main
struct CabinetIQApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("cabinetiq.hasCompletedOnboarding") private var hasCompletedOnboarding = false
    private let persistence = PersistenceController.shared

    init() {
        ReminderService.shared.prepareAuthorization()
        SearchIndex.shared.bootstrapIfNeeded(context: persistence.container.viewContext)
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    RootTabView()
                } else {
                    OnboardingView(hasCompleted: $hasCompletedOnboarding)
                }
            }
            .environment(\.managedObjectContext, persistence.container.viewContext)
            .environmentObject(ReminderService.shared)
            .environmentObject(SearchIndex.shared)
            .environmentObject(RAGEngine.shared)
            .preferredColorScheme(.dark)
            .onOpenURL { url in
                guard url.scheme == "cabinetiq" else { return }
                Task {
                    await ShareImportHandler.shared.processPendingImports(context: persistence.container.viewContext)
                }
            }
            .task {
                await ShareImportHandler.shared.processPendingImports(context: persistence.container.viewContext)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                persistence.save()
            }
        }
    }

    private func configureAppearance() {
        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.backgroundColor = UIColor(Theme.background)
        nav.titleTextAttributes = [.foregroundColor: UIColor(Theme.ink)]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor(Theme.ink)]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().tintColor = UIColor(Theme.accent)

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor(Theme.background)
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }
}
