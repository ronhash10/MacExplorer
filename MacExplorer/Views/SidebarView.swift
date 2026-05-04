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
                        .dropDestination(for: URL.self) { urls, _ in
                            moveFiles(urls, to: location.url)
                            return true
                        }
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

    private func moveFiles(_ urls: [URL], to destination: URL) {
        for url in urls {
            let target = destination.appendingPathComponent(url.lastPathComponent)
            guard url.deletingLastPathComponent().standardizedFileURL != destination.standardizedFileURL else { continue }
            try? FileManager.default.moveItem(at: url, to: target)
        }
        appState.refreshCurrentTab()
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
    @State private var isRenaming = false
    @State private var renameText = ""

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
                    .fontWeight(url.standardizedFileURL == activePath.standardizedFileURL ? .bold : .regular)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appState.navigate(to: url)
                        isExpanded = true
                        isLoaded = false
                        loadChildrenIfNeeded()
                    }
                    .popover(isPresented: $isRenaming, arrowEdge: .trailing) {
                        RenamePopoverContent(
                            text: $renameText,
                            onCommit: { commitRename() },
                            onCancel: { isRenaming = false }
                        )
                    }
                    .dropDestination(for: URL.self) { urls, _ in
                        moveFiles(urls, to: url)
                        return true
                    }
                    .contextMenu {
                        Button("Open in New Tab") {
                            appState.addTab(path: url)
                        }
                        Divider()
                        Button("Rename") {
                            renameText = url.lastPathComponent
                            isRenaming = true
                        }
                        Button("New Folder") {
                            createNewFolder(in: url)
                        }
                        Divider()
                        Button("Move to Trash", role: .destructive) {
                            trashFolder(url)
                        }
                    }
            }
            .tag(url)
            .onAppear {
                loadChildrenIfNeeded()
                if isOnActivePath { isExpanded = true }
            }
            .onChange(of: activePath) {
                if isOnActivePath {
                    isExpanded = true
                    isLoaded = false
                    loadChildrenIfNeeded()
                }
                // If this exact folder was selected, expand it
                if activePath.standardizedFileURL == url.standardizedFileURL {
                    isExpanded = true
                    isLoaded = false
                    loadChildrenIfNeeded()
                }
            }
        } else {
            Label(url.lastPathComponent, systemImage: "folder")
                .tag(url)
                .contentShape(Rectangle())
                .onTapGesture {
                    appState.navigate(to: url)
                }
                .popover(isPresented: $isRenaming, arrowEdge: .trailing) {
                    RenamePopoverContent(
                        text: $renameText,
                        onCommit: { commitRename() },
                        onCancel: { isRenaming = false }
                    )
                }
                .dropDestination(for: URL.self) { urls, _ in
                    moveFiles(urls, to: url)
                    return true
                }
                .contextMenu {
                    Button("Open in New Tab") {
                        appState.addTab(path: url)
                    }
                    Divider()
                    Button("Rename") {
                        renameText = url.lastPathComponent
                        isRenaming = true
                    }
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

    private func moveFiles(_ urls: [URL], to destination: URL) {
        for url in urls {
            let target = destination.appendingPathComponent(url.lastPathComponent)
            guard url.deletingLastPathComponent().standardizedFileURL != destination.standardizedFileURL else { continue }
            try? FileManager.default.moveItem(at: url, to: target)
        }
        appState.refreshCurrentTab()
    }

    private func commitRename() {
        isRenaming = false
        let newName = renameText.trimmingCharacters(in: .whitespaces)
        guard !newName.isEmpty, newName != url.lastPathComponent else { return }
        let newURL = url.deletingLastPathComponent().appendingPathComponent(newName, isDirectory: true)
        try? FileManager.default.moveItem(at: url, to: newURL)
        appState.navigate(to: newURL.standardizedFileURL)
        // Wait for tree to reload then scroll
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            Self.scrollSidebarToSelection()
        }
    }

    /// Walk all windows to find NSOutlineView and scroll the selected row into view.
    static func scrollSidebarToSelection() {
        for window in NSApp.windows {
            guard let contentView = window.contentView else { continue }
            var outlines: [NSOutlineView] = []
            Self.findAllOutlineViews(in: contentView, results: &outlines)
            for outline in outlines {
                let row = outline.selectedRow
                if row >= 0 {
                    outline.scrollRowToVisible(row)
                    return
                }
            }
        }
    }

    private static func findAllOutlineViews(in view: NSView, results: inout [NSOutlineView]) {
        if let outline = view as? NSOutlineView { results.append(outline) }
        for subview in view.subviews {
            findAllOutlineViews(in: subview, results: &results)
        }
    }

    private static func findOutlineViewIn(_ view: NSView) -> NSOutlineView? {
        if let outline = view as? NSOutlineView { return outline }
        for subview in view.subviews {
            if let found = findOutlineViewIn(subview) { return found }
        }
        return nil
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

