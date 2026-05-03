import SwiftUI

@main
struct MacExplorerApp: App {
    @State private var appState = AppState()
    @State private var showFullDiskAccessAlert = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .frame(minWidth: 800, minHeight: 500)
                .onAppear {
                    checkFullDiskAccess()
                }
                .alert("Full Disk Access Required", isPresented: $showFullDiskAccessAlert) {
                    Button("Open System Settings") {
                        NSWorkspace.shared.open(
                            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
                        )
                        // Reveal the .app bundle in Finder so the user can drag it into the list
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            let appURL = URL(fileURLWithPath: Bundle.main.executablePath!)
                                .deletingLastPathComponent() // MacOS/
                                .deletingLastPathComponent() // Contents/
                                .deletingLastPathComponent() // MacExplorer.app
                            NSWorkspace.shared.activateFileViewerSelecting([appURL])
                        }
                    }
                    Button("Later", role: .cancel) {}
                } message: {
                    Text("MacExplorer needs Full Disk Access to browse all folders.\n\n1. Click \"Open System Settings\" below\n2. Click the + button in Full Disk Access\n3. Select MacExplorer from the Finder window that opens\n\nAlternatively, drag MacExplorer.app into the list.")
                }
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

    /// Check if we can read a protected directory as a proxy for Full Disk Access.
    private func checkFullDiskAccess() {
        let testPaths = [
            "\(NSHomeDirectory())/Library/Safari",
            "\(NSHomeDirectory())/Library/Mail"
        ]
        let hasAccess = testPaths.contains { path in
            FileManager.default.isReadableFile(atPath: path)
        }
        if !hasAccess {
            showFullDiskAccessAlert = true
        }
    }
}
