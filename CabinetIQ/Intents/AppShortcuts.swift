import AppIntents

struct CabinetIQShortcutsProvider: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .cyan

    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: AskCabinetIQIntent(), phrases: ["Ask Cabinet about \(.applicationName)", "Ask CabinetIQ"], shortTitle: "Ask CabinetIQ", systemImageName: "questionmark.bubble")
    }
}
