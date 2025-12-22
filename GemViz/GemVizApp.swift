import SwiftUI

@main
struct GemVizApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open...") {
                    NotificationCenter.default.post(name: .openFile, object: nil)
                }
                .keyboardShortcut("o")
            }
        }
    }
}

extension Notification.Name {
    static let openFile = Notification.Name("openFile")
}
