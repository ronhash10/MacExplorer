import SwiftUI

@main
struct MacExplorerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ExplorerWindow()
                .frame(minWidth: 800, minHeight: 500)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Tab") {
                    NotificationCenter.default.post(name: .newTab, object: nil)
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("Close Tab") {
                    NotificationCenter.default.post(name: .closeTab, object: nil)
                }
                .keyboardShortcut("w", modifiers: .command)
            }

            CommandGroup(after: .toolbar) {
                Button("Toggle Preview") {
                    NotificationCenter.default.post(name: .togglePreview, object: nil)
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }

            CommandGroup(after: .toolbar) {
                Button("Back") {
                    NotificationCenter.default.post(name: .navigateBack, object: nil)
                }
                .keyboardShortcut("[", modifiers: .command)

                Button("Forward") {
                    NotificationCenter.default.post(name: .navigateForward, object: nil)
                }
                .keyboardShortcut("]", modifiers: .command)

                Button("Move to Trash") {
                    NotificationCenter.default.post(name: .moveToTrash, object: nil)
                }
                .keyboardShortcut(.delete, modifiers: .command)
            }
        }

        Settings {
            SettingsView()
        }
    }
}

// Notifications for menu commands → active window
extension Notification.Name {
    static let newTab = Notification.Name("MacExplorer.newTab")
    static let closeTab = Notification.Name("MacExplorer.closeTab")
    static let togglePreview = Notification.Name("MacExplorer.togglePreview")
    static let navigateBack = Notification.Name("MacExplorer.navigateBack")
    static let navigateForward = Notification.Name("MacExplorer.navigateForward")
    static let moveToTrash = Notification.Name("MacExplorer.moveToTrash")
    static let settingsChanged = Notification.Name("MacExplorer.settingsChanged")
}

/// Each window gets its own AppState, registered with the global WindowManager.
struct ExplorerWindow: View {
    @State private var appState = AppState()
    @State private var showFullDiskAccessAlert = false

    var body: some View {
        ContentView()
            .environment(appState)
            .onAppear {
                WindowManager.shared.register(appState)
                checkFullDiskAccess()
                handleLaunchArguments()
            }
            .onDisappear {
                WindowManager.shared.unregister(appState.windowID)
            }
            .onChange(of: appState.shouldClose) {
                if appState.shouldClose {
                    // Close this window if all tabs were dragged out
                    NSApp.keyWindow?.close()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .newTab)) { _ in
                if NSApp.keyWindow == findMyWindow() {
                    appState.addTab()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .closeTab)) { _ in
                if NSApp.keyWindow == findMyWindow() {
                    appState.closeCurrentTab()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .togglePreview)) { _ in
                if NSApp.keyWindow == findMyWindow() {
                    appState.showPreview.toggle()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateBack)) { _ in
                if NSApp.keyWindow == findMyWindow() {
                    appState.currentTab?.goBack()
                    appState.refreshCurrentTab()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateForward)) { _ in
                if NSApp.keyWindow == findMyWindow() {
                    appState.currentTab?.goForward()
                    appState.refreshCurrentTab()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .moveToTrash)) { _ in
                if NSApp.keyWindow == findMyWindow(), let tab = appState.currentTab {
                    let items = tab.items.filter { tab.selectedItems.contains($0.id) }
                    guard !items.isEmpty else { return }
                    TrashHelper.moveToTrash(items.map(\.url), using: appState.fileService) {
                        appState.refreshCurrentTab()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .settingsChanged)) { _ in
                appState.showPreview = UserDefaults.standard.object(forKey: "showPreview") as? Bool ?? true
                appState.showHiddenFiles = UserDefaults.standard.bool(forKey: "showHiddenFiles")
            }
            .alert("Full Disk Access Required", isPresented: $showFullDiskAccessAlert) {
                Button("Open System Settings") {
                    NSWorkspace.shared.open(
                        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
                    )
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        let appURL = URL(fileURLWithPath: Bundle.main.executablePath!)
                            .deletingLastPathComponent()
                            .deletingLastPathComponent()
                            .deletingLastPathComponent()
                        NSWorkspace.shared.activateFileViewerSelecting([appURL])
                    }
                }
                Button("Later", role: .cancel) {}
            } message: {
                Text("MacExplorer needs Full Disk Access to browse all folders.\n\n1. Click \"Open System Settings\" below\n2. Click the + button in Full Disk Access\n3. Select MacExplorer from the Finder window that opens\n\nAlternatively, drag MacExplorer.app into the list.")
            }
    }

    private func findMyWindow() -> NSWindow? {
        NSApp.windows.first { window in
            window.contentView?.subviews.contains(where: { _ in true }) == true &&
            window.isKeyWindow
        }
    }

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

    private func handleLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        for arg in args.dropFirst() where !arg.hasPrefix("-") {
            let url = URL(fileURLWithPath: arg)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                appState.navigate(to: url)
                return
            }
        }
    }
}

/// Handles folder open events from macOS.
class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        // Open folders in the key window's state, or the first available window
        let targetState = WindowManager.shared.windowStates.values.first
        for url in urls {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                targetState?.navigate(to: url)
            }
        }
    }
}
