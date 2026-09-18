import AppIntents

struct CabinetIQShortcutsProvider: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .yellow

    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: AskCabinetIQIntent(), phrases: ["Ask Cabinet about \(.applicationName)", "Ask CabinetIQ"], shortTitle: "Ask CabinetIQ", systemImageName: "questionmark.bubble")
    }
}
