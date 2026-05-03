import SwiftUI

@main
struct MacExplorerApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .frame(minWidth: 800, minHeight: 500)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Tab") {
                    appState.addTab()
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("Close Tab") {
                    appState.closeCurrentTab()
                }
                .keyboardShortcut("w", modifiers: .command)
            }

            CommandGroup(after: .toolbar) {
                Button("Toggle Preview") {
                    appState.showPreview.toggle()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }

            CommandGroup(after: .toolbar) {
                Button("Back") {
                    appState.currentTab?.goBack()
                }
                .keyboardShortcut("[", modifiers: .command)

                Button("Forward") {
                    appState.currentTab?.goForward()
                }
                .keyboardShortcut("]", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environment(appState)
        }
    }
}
