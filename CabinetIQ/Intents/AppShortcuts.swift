import AppIntents

struct CabinetIQShortcutsProvider: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .teal

    static var appShortcuts: [AppShortcut] {
        [
            // General-purpose ask shortcut
            AppShortcut(
                intent: AskCabinetIQIntent(),
                phrases: [
                    "Ask CabinetIQ in ${applicationName}",
                    "Ask ${applicationName}",
                    "Ask a question in ${applicationName}",
                    "CabinetIQ, ${applicationName}",
                    "Question for ${applicationName}"
                ],
                shortTitle: "Ask CabinetIQ",
                systemImageName: "questionmark.bubble"
            ),

            // MOT due date (leverages Ask intent with natural phrases users might say)
            AppShortcut(
                intent: AskCabinetIQIntent(),
                phrases: [
                    "When is my MOT due in ${applicationName}",
                    "Ask ${applicationName} when my MOT is due",
                    "When does my MOT expire in ${applicationName}",
                    "MOT expiry in ${applicationName}"
                ],
                shortTitle: "When is my MOT due?",
                systemImageName: "car.fill"
            ),

            // Mortgage rate and fix end
            AppShortcut(
                intent: AskCabinetIQIntent(),
                phrases: [
                    "What is my mortgage rate in ${applicationName}",
                    "Ask ${applicationName} my mortgage rate",
                    "When does my mortgage fix end in ${applicationName}",
                    "Mortgage details in ${applicationName}"
                ],
                shortTitle: "Mortgage rate & fix end",
                systemImageName: "house.fill"
            ),

            // Insurance due date (vehicle/home)
            AppShortcut(
                intent: AskCabinetIQIntent(),
                phrases: [
                    "When is my insurance due in ${applicationName}",
                    "Ask ${applicationName} when my insurance is due",
                    "Insurance expiry in ${applicationName}"
                ],
                shortTitle: "When is insurance due?",
                systemImageName: "shield.checkerboard"
            )
        ]
    }
}
