import SwiftUI

/// Sidebar folder tree with quick-access locations and expandable directories.
struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @Bindable var tab: TabState

    private var treeRoot: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let current = tab.currentPath.standardizedFileURL
        // If current path is under home, root at home; otherwise root at volume
        if current.path.hasPrefix(home.path) {
            return home
        }
        // Find the volume root
        let components = current.pathComponents
        if components.count >= 3 && components[1] == "Volumes" {
            return URL(fileURLWithPath: "/" + components[1] + "/" + components[2])
        }
        return URL(fileURLWithPath: "/")
    }

    var body: some View {
        List(selection: Binding(
            get: { tab.currentPath },
            set: { url in
                if let url { appState.navigate(to: url) }
            }
        )) {
            Section("Favorites") {
                ForEach(appState.fileService.sidebarLocations, id: \.url) { location in
                    Label(location.name, systemImage: location.icon)
                        .tag(location.url)
                        .contextMenu {
                            Button("Open in New Tab") {
                                appState.addTab(path: location.url)
                            }
                            Divider()
                            Button("New Folder") {
                                createNewFolder(in: location.url)
                            }
                        }
                }
            }

            Section("Volumes") {
                ForEach(appState.fileService.volumes, id: \.self) { volume in
                    Label(volume.lastPathComponent, systemImage: "externaldrive")
                        .tag(volume)
                        .contextMenu {
                            Button("Open in New Tab") {
                                appState.addTab(path: volume)
                            }
                        }
                }
            }

            Section("Folders") {
                FolderTreeNode(url: treeRoot, activePath: tab.currentPath, depth: 0)
            }
        }
        .listStyle(.sidebar)
    }

    private func createNewFolder(in parentURL: URL) {
        let baseName = "New Folder"
        var name = baseName
        var counter = 1
        while FileManager.default.fileExists(atPath: parentURL.appendingPathComponent(name).path) {
            counter += 1
            name = "\(baseName) \(counter)"
        }
        _ = try? appState.fileService.createFolder(at: parentURL, name: name)
        appState.navigate(to: parentURL)
        appState.pendingRenameFolder = name
    }
}

/// A recursive folder tree node that auto-expands along the active path.
struct FolderTreeNode: View {
    @Environment(AppState.self) private var appState
    let url: URL
    let activePath: URL
    let depth: Int

    @State private var children: [URL] = []
    @State private var isLoaded = false
    @State private var isExpanded = false

    private static let maxDepth = 10

    /// Whether this node is an ancestor of (or equal to) the active path.
    private var isOnActivePath: Bool {
        activePath.standardizedFileURL.path.hasPrefix(url.standardizedFileURL.path)
    }

    var body: some View {
        if depth < Self.maxDepth {
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(children, id: \.self) { childURL in
                    FolderTreeNode(url: childURL, activePath: activePath, depth: depth + 1)
                }
            } label: {
                Label(url.lastPathComponent, systemImage: isOnActivePath ? "folder.fill" : "folder")
                    .tag(url)
                    .fontWeight(url.standardizedFileURL == activePath.standardizedFileURL ? .bold : .regular)
                    .onTapGesture {
                        appState.navigate(to: url)
                    }
                    .contextMenu {
                        Button("Open in New Tab") {
                            appState.addTab(path: url)
                        }
                        Divider()
                        Button("New Folder") {
                            createNewFolder(in: url)
                        }
                        Divider()
                        Button("Move to Trash", role: .destructive) {
                            trashFolder(url)
                        }
                    }
            }
            .onAppear {
                loadChildrenIfNeeded()
                if isOnActivePath { isExpanded = true }
            }
            .onChange(of: activePath) {
                if isOnActivePath {
                    isExpanded = true
                    // Reload children so newly navigated-to folders appear
                    isLoaded = false
                    loadChildrenIfNeeded()
                }
            }
        } else {
            Label(url.lastPathComponent, systemImage: "folder")
                .tag(url)
                .onTapGesture {
                    appState.navigate(to: url)
                }
                .contextMenu {
                    Button("Open in New Tab") {
                        appState.addTab(path: url)
                    }
                    Divider()
                    Button("New Folder") {
                        createNewFolder(in: url)
                    }
                    Divider()
                    Button("Move to Trash", role: .destructive) {
                        trashFolder(url)
                    }
                }
        }
    }

    private func trashFolder(_ folderURL: URL) {
        TrashHelper.moveToTrash([folderURL], using: appState.fileService) {
            if appState.currentTab?.currentPath.standardizedFileURL.path
                .hasPrefix(folderURL.standardizedFileURL.path) == true {
                appState.navigate(to: folderURL.deletingLastPathComponent())
            }
            appState.refreshCurrentTab()
        }
    }

    private func createNewFolder(in parentURL: URL) {
        let baseName = "New Folder"
        var name = baseName
        var counter = 1
        while FileManager.default.fileExists(atPath: parentURL.appendingPathComponent(name).path) {
            counter += 1
            name = "\(baseName) \(counter)"
        }
        _ = try? appState.fileService.createFolder(at: parentURL, name: name)
        isLoaded = false
        loadChildrenIfNeeded()
        appState.navigate(to: parentURL)
        appState.pendingRenameFolder = name
    }

    private func loadChildrenIfNeeded() {
        guard !isLoaded else { return }
        isLoaded = true
        children = appState.fileService.contentsOfDirectory(at: url)
            .filter(\.isDirectory)
            .map(\.url)
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }
}
