import AppIntents

@available(iOS 17.0, *)
struct PickupCodeShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RecognizePickupCodeIntent(),
            phrases: [
                "识别截图取码 \(.applicationName)",
                "识别取码 \(.applicationName)",
                "用 \(.applicationName) 识别截图"
            ],
            shortTitle: "识别截图取码",
            systemImageName: "text.viewfinder"
        )
    }
}
