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

            CommandGroup(replacing: .pasteboard) {
                Button("Copy") {
                    NotificationCenter.default.post(name: .copyFiles, object: nil)
                }
                .keyboardShortcut("c", modifiers: .command)

                Button("Paste") {
                    NotificationCenter.default.post(name: .pasteFiles, object: nil)
                }
                .keyboardShortcut("v", modifiers: .command)
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
    static let copyFiles = Notification.Name("MacExplorer.copyFiles")
    static let pasteFiles = Notification.Name("MacExplorer.pasteFiles")
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
                    let allItems = tab.items
                    let deletedIDs = Set(items.map(\.id))
                    var nextName: String?
                    if let lastIndex = allItems.lastIndex(where: { deletedIDs.contains($0.id) }) {
                        if lastIndex + 1 < allItems.count, !deletedIDs.contains(allItems[lastIndex + 1].id) {
                            nextName = allItems[lastIndex + 1].name
                        } else if let prev = allItems[0...lastIndex].last(where: { !deletedIDs.contains($0.id) }) {
                            nextName = prev.name
                        }
                    }
                    TrashHelper.moveToTrash(items.map(\.url), using: appState.fileService) {
                        appState.refreshCurrentTab()
                        if let nextName {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                if let item = tab.items.first(where: { $0.name == nextName }) {
                                    tab.selectedItems = [item.id]
                                    appState.scrollToItemID = item.id
                                }
                            }
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .copyFiles)) { _ in
                if NSApp.keyWindow == findMyWindow(), let tab = appState.currentTab {
                    let items = tab.items.filter { tab.selectedItems.contains($0.id) }
                    guard !items.isEmpty else { return }
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.writeObjects(items.map(\.url) as [NSURL])
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .pasteFiles)) { _ in
                if NSApp.keyWindow == findMyWindow(), let tab = appState.currentTab {
                    guard let urls = NSPasteboard.general.readObjects(forClasses: [NSURL.self], options: [
                        .urlReadingFileURLsOnly: true
                    ]) as? [URL], !urls.isEmpty else { return }
                    let dest = tab.currentPath
                    var pastedNames: [String] = []
                    for url in urls {
                        let target = dest.appendingPathComponent(url.lastPathComponent)
                        let finalTarget = uniqueURL(for: target)
                        try? FileManager.default.copyItem(at: url, to: finalTarget)
                        pastedNames.append(finalTarget.lastPathComponent)
                    }
                    appState.refreshCurrentTab()
                    if let lastName = pastedNames.last {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            if let item = tab.items.first(where: { $0.name == lastName }) {
                                tab.selectedItems = Set(tab.items.filter { pastedNames.contains($0.name) }.map(\.id))
                                appState.scrollToItemID = item.id
                            }
                        }
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

    /// Returns a unique file URL by appending " copy", " copy 2", etc. if the target already exists.
    private func uniqueURL(for url: URL) -> URL {
        guard FileManager.default.fileExists(atPath: url.path) else { return url }
        let dir = url.deletingLastPathComponent()
        let ext = url.pathExtension
        let baseName = ext.isEmpty ? url.lastPathComponent : url.deletingPathExtension().lastPathComponent
        var counter = 0
        while true {
            let suffix = counter == 0 ? " copy" : " copy \(counter + 1)"
            let newName = ext.isEmpty ? "\(baseName)\(suffix)" : "\(baseName)\(suffix).\(ext)"
            let candidate = dir.appendingPathComponent(newName)
            if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            counter += 1
        }
    }
}

/// Handles folder open events from macOS.
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set the app icon for the Dock — find it relative to the executable in the .app bundle
        let execURL = URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])
        let resourcesURL = execURL
            .deletingLastPathComponent()  // Contents/MacOS
            .deletingLastPathComponent()  // Contents
            .appendingPathComponent("Resources")
            .appendingPathComponent("AppIcon.icns")
        if let icon = NSImage(contentsOf: resourcesURL) {
            NSApp.applicationIconImage = icon
        }
    }

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
