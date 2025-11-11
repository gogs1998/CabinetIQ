import SwiftUI
import CoreData

@main
struct CabinetIQApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let persistence = PersistenceController.shared

    init() {
        ReminderService.shared.prepareAuthorization()
        SearchIndex.shared.bootstrapIfNeeded(context: persistence.container.viewContext)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
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
}
