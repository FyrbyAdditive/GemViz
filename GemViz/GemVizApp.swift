import SwiftUI

@main
struct GemVizApp: App {
    @State private var aboutWindow: NSWindow?

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    if url.pathExtension.lowercased() == "gem" {
                        NotificationCenter.default.post(name: .openFileURL, object: url)
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open...") {
                    NotificationCenter.default.post(name: .openFile, object: nil)
                }
                .keyboardShortcut("o")
            }
            CommandGroup(replacing: .appInfo) {
                Button("About GemViz") {
                    showAboutWindow()
                }
            }
        }
    }

    private func showAboutWindow() {
        if let existingWindow = aboutWindow, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About GemViz"
        window.contentView = NSHostingView(rootView: AboutView())
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        aboutWindow = window
    }
}

extension Notification.Name {
    static let openFile = Notification.Name("openFile")
    static let openFileURL = Notification.Name("openFileURL")
}
