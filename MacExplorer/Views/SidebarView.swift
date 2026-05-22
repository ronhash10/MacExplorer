import SwiftUI
import UniformTypeIdentifiers

/// Sidebar folder tree with quick-access locations and expandable directories.
/// Uses ScrollView + LazyVStack instead of List so ScrollViewReader works for programmatic scrolling.
struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @Bindable var tab: TabState

    /// Tracks which folders are expanded by their standardized path
    @State private var expandedPaths: Set<String> = []
    /// Rename state
    @State private var renamingURL: URL?
    @State private var renameText: String = ""
    /// Reload counter to force tree refresh
    @State private var reloadToken: Int = 0
    /// Cache of directory children to avoid repeated filesystem reads
    @State private var childrenCache: [String: [URL]] = [:]
    /// Tracks which folder path is currently a drop target
    @State private var dropTargetPath: String?
    /// Delete confirmation
    @State private var folderToDelete: URL?
    @State private var showDeleteConfirmation = false
    @State private var deleteConfirmationMessage = ""

    private var treeRoot: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let current = tab.currentPath.standardizedFileURL
        if current.path.hasPrefix(home.path) {
            return home
        }
        let components = current.pathComponents
        if components.count >= 3 && components[1] == "Volumes" {
            return URL(fileURLWithPath: "/" + components[1] + "/" + components[2])
        }
        return URL(fileURLWithPath: "/")
    }

    /// Represents a single visible row in the flattened tree
    private struct FlatNode: Identifiable {
        let url: URL
        let depth: Int
        let hasChildren: Bool
        var id: String { url.standardizedFileURL.path }
    }

    /// Hidden ancestor paths that must be visible in the tree even when "show hidden" is off
    @State private var forcedVisiblePaths: Set<String> = []

    /// Flatten the tree: only include children of expanded nodes
    private var visibleNodes: [FlatNode] {
        _ = reloadToken
        var result: [FlatNode] = []
        func visit(_ url: URL, depth: Int) {
            let stdPath = url.standardizedFileURL.path
            let children = cachedChildren(of: url)
            result.append(FlatNode(url: url, depth: depth, hasChildren: !children.isEmpty))
            if expandedPaths.contains(stdPath) {
                for child in children {
                    visit(child, depth: depth + 1)
                }
            }
        }
        visit(treeRoot, depth: 0)
        return result
    }

    /// Load children with caching to avoid repeated I/O
    private func cachedChildren(of url: URL) -> [URL] {
        let key = url.standardizedFileURL.path
        if let cached = childrenCache[key] {
            return cached
        }
        let children = loadChildren(of: url)
        DispatchQueue.main.async {
            childrenCache[key] = children
        }
        return children
    }

    private func loadChildren(of url: URL) -> [URL] {
        var children = appState.fileService.contentsOfDirectory(at: url, showHidden: appState.showHiddenFiles)
            .filter(\.isDirectory)
            .map(\.url)

        // Include hidden ancestor folders needed for the current path
        for forced in forcedVisiblePaths {
            let forcedURL = URL(fileURLWithPath: forced)
            if forcedURL.deletingLastPathComponent().standardizedFileURL == url.standardizedFileURL {
                if !children.contains(where: { $0.standardizedFileURL.path == forced }) {
                    children.append(forcedURL)
                }
            }
        }

        return children.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    /// Invalidate cache for a specific path (e.g. after rename, create, move)
    private func invalidateCache(for url: URL? = nil) {
        if let url {
            childrenCache.removeValue(forKey: url.standardizedFileURL.path)
        } else {
            childrenCache.removeAll()
        }
    }

    /// Ensure all ancestors of a path are expanded, including hidden folders
    private func expandAncestors(of targetURL: URL) {
        let rootPath = treeRoot.standardizedFileURL.path
        let targetPath = targetURL.standardizedFileURL.path
        guard targetPath.hasPrefix(rootPath) else { return }

        var current = treeRoot.standardizedFileURL
        expandedPaths.insert(current.path)
        let rootComponents = treeRoot.standardizedFileURL.pathComponents
        let targetComponents = targetURL.standardizedFileURL.pathComponents
        var needsCacheInvalidation = false
        for i in rootComponents.count..<targetComponents.count {
            current = current.appendingPathComponent(targetComponents[i])
            let stdPath = current.standardizedFileURL.path
            expandedPaths.insert(stdPath)

            // If this is a hidden folder, force it visible in the tree
            if targetComponents[i].hasPrefix(".") {
                if !forcedVisiblePaths.contains(stdPath) {
                    forcedVisiblePaths.insert(stdPath)
                    // Invalidate parent's cache so it picks up the forced path
                    invalidateCache(for: current.deletingLastPathComponent())
                    needsCacheInvalidation = true
                }
            }
        }
        if needsCacheInvalidation {
            reloadToken += 1
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // MARK: Favorites
                    sidebarSectionHeader("Favorites")
                    ForEach(appState.fileService.sidebarLocations, id: \.url) { location in
                        sidebarRow(
                            label: location.name,
                            icon: location.icon,
                            url: location.url,
                            depth: 0,
                            isSelected: tab.currentPath.standardizedFileURL == location.url.standardizedFileURL
                        )
                        .onDrop(of: [.url, .fileURL], isTargeted: nil) { providers in
                            handleDrop(providers: providers, destination: location.url)
                        }
                        .contextMenu {
                            Button("Open in New Tab") { appState.addTab(path: location.url) }
                            Divider()
                            Button("New Folder") { createNewFolder(in: location.url) }
                        }
                    }

                    // MARK: Volumes
                    sidebarSectionHeader("Volumes")
                    ForEach(appState.fileService.volumes, id: \.self) { volume in
                        sidebarRow(
                            label: volume.lastPathComponent,
                            icon: "externaldrive",
                            url: volume,
                            depth: 0,
                            isSelected: tab.currentPath.standardizedFileURL == volume.standardizedFileURL
                        )
                        .contextMenu {
                            Button("Open in New Tab") { appState.addTab(path: volume) }
                        }
                    }

                    // MARK: Folders tree
                    sidebarSectionHeader("Folders")
                    ForEach(visibleNodes) { node in
                        folderRow(node: node)
                            .id(node.id)
                    }
                }
                .padding(.vertical, 4)
            }
            .onAppear {
                expandAncestors(of: tab.currentPath)
                let targetID = tab.currentPath.standardizedFileURL.path
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation {
                        proxy.scrollTo(targetID, anchor: .center)
                    }
                }
            }
            .onChange(of: tab.currentPath) {
                expandAncestors(of: tab.currentPath)
                let targetID = tab.currentPath.standardizedFileURL.path
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation {
                        proxy.scrollTo(targetID, anchor: .center)
                    }
                }
            }
            .onChange(of: appState.sidebarScrollTarget) { _, target in
                guard let target else { return }
                appState.sidebarScrollTarget = nil
                let targetID = target.standardizedFileURL.path
                expandAncestors(of: target)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation {
                        proxy.scrollTo(targetID, anchor: .center)
                    }
                }
            }
            .onChange(of: appState.sidebarReloadToken) {
                invalidateCache()
                reloadToken += 1
            }
            .onChange(of: expandedPaths) {
                appState.watchedSidebarPaths = expandedPaths
            }
            .onDeleteCommand {
                confirmDelete(folder: tab.currentPath)
            }
        }
        .alert("Move to Trash", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { folderToDelete = nil }
            Button("Move to Trash", role: .destructive) {
                if let folder = folderToDelete {
                    trashFolder(folder)
                    folderToDelete = nil
                }
            }
        } message: {
            Text(deleteConfirmationMessage)
        }
    }

    // MARK: - Section Header

    @ViewBuilder
    private func sidebarSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 2)
    }

    // MARK: - Generic Sidebar Row (favorites/volumes)

    @ViewBuilder
    private func sidebarRow(label: String, icon: String, url: URL, depth: Int, isSelected: Bool) -> some View {
        HStack(spacing: 4) {
            Color.clear.frame(width: 16, height: 16)
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(label)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .padding(.leading, CGFloat(depth) * 16)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                .padding(.horizontal, 4)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            appState.navigate(to: url)
        }
    }

    // MARK: - Folder Tree Row

    @ViewBuilder
    private func folderRow(node: FlatNode) -> some View {
        let stdPath = node.url.standardizedFileURL.path
        let isExpanded = expandedPaths.contains(stdPath)
        let isActive = tab.currentPath.standardizedFileURL.path.hasPrefix(stdPath)
        let isSelected = tab.currentPath.standardizedFileURL == node.url.standardizedFileURL
        let isBeingRenamed = renamingURL?.standardizedFileURL == node.url.standardizedFileURL

        HStack(spacing: 4) {
            // Disclosure chevron
            if node.hasChildren {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            if isExpanded {
                                expandedPaths.remove(stdPath)
                            } else {
                                expandedPaths.insert(stdPath)
                            }
                        }
                    }
            } else {
                Color.clear.frame(width: 16, height: 16)
            }

            Image(systemName: isActive ? "folder.fill" : "folder")
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(node.url.lastPathComponent)
                .fontWeight(isSelected ? .bold : .regular)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .padding(.leading, CGFloat(node.depth) * 16)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(dropTargetPath == stdPath ? Color.accentColor.opacity(0.35) :
                      isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                .padding(.horizontal, 4)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            appState.navigate(to: node.url)
            if node.hasChildren {
                _ = withAnimation(.easeInOut(duration: 0.15)) {
                    expandedPaths.insert(stdPath)
                }
            }
        }
        .popover(isPresented: Binding(
            get: { isBeingRenamed },
            set: { if !$0 { renamingURL = nil } }
        ), arrowEdge: .trailing) {
            RenamePopoverContent(
                text: $renameText,
                onCommit: {
                    commitRename(from: node.url)
                },
                onCancel: { renamingURL = nil }
            )
        }
        .onDrop(of: [.url, .fileURL], isTargeted: Binding(
            get: { dropTargetPath == stdPath },
            set: { targeted in
                if targeted { dropTargetPath = stdPath }
                else if dropTargetPath == stdPath { dropTargetPath = nil }
            }
        )) { providers in
            handleDrop(providers: providers, destination: node.url)
        }
        .contextMenu {
            Button("Open in New Tab") { appState.addTab(path: node.url) }
            Divider()
            Button("Rename") {
                renameText = node.url.lastPathComponent
                renamingURL = node.url
            }
            Button("New Folder") { createNewFolder(in: node.url) }
            Divider()
            Button("Move to Trash", role: .destructive) { confirmDelete(folder: node.url) }
        }
    }

    // MARK: - Actions

    private func confirmDelete(folder: URL) {
        // Don't allow deleting the tree root or home
        let home = FileManager.default.homeDirectoryForCurrentUser
        guard folder.standardizedFileURL != home.standardizedFileURL,
              folder.standardizedFileURL != treeRoot.standardizedFileURL else { return }

        let contents = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        let itemCount = contents.filter { !$0.hasPrefix(".") }.count

        folderToDelete = folder
        if itemCount > 0 {
            deleteConfirmationMessage = "\"\(folder.lastPathComponent)\" contains \(itemCount) item\(itemCount == 1 ? "" : "s"). Are you sure you want to move it to the Trash?"
        } else {
            deleteConfirmationMessage = "Are you sure you want to move \"\(folder.lastPathComponent)\" to the Trash?"
        }
        showDeleteConfirmation = true
    }

    private func commitRename(from oldURL: URL) {
        renamingURL = nil
        let newName = renameText.trimmingCharacters(in: .whitespaces)
        guard !newName.isEmpty, newName != oldURL.lastPathComponent else { return }
        let newURL = oldURL.deletingLastPathComponent().appendingPathComponent(newName, isDirectory: true)

        guard appState.renameWithUndo(at: oldURL, to: newName) != nil else { return }

        // Update expanded paths: replace old path with new
        let oldPath = oldURL.standardizedFileURL.path
        let newPath = newURL.standardizedFileURL.path
        let pathsToUpdate = expandedPaths.filter { $0.hasPrefix(oldPath) }
        for path in pathsToUpdate {
            expandedPaths.remove(path)
            expandedPaths.insert(path.replacingOccurrences(of: oldPath, with: newPath))
        }

        invalidateCache()
        reloadToken += 1

        // Refresh file list if the renamed folder's parent is currently displayed
        let parentPath = oldURL.deletingLastPathComponent().standardizedFileURL
        if tab.currentPath.standardizedFileURL == parentPath {
            appState.refreshCurrentTab()
        }

        appState.sidebarScrollTarget = newURL.standardizedFileURL
    }

    private func createNewFolder(in parentURL: URL) {
        let baseName = "New Folder"
        var name = baseName
        var counter = 1
        while FileManager.default.fileExists(atPath: parentURL.appendingPathComponent(name).path) {
            counter += 1
            name = "\(baseName) \(counter)"
        }
        guard appState.createFolderWithUndo(at: parentURL, name: name) != nil else { return }
        invalidateCache(for: parentURL)
        reloadToken += 1
        expandedPaths.insert(parentURL.standardizedFileURL.path)

        // Open rename popover on the new folder in the sidebar
        let newFolderURL = parentURL.appendingPathComponent(name)
        renameText = name
        renamingURL = newFolderURL

        // Refresh file list if we're already viewing this parent
        if tab.currentPath.standardizedFileURL == parentURL.standardizedFileURL {
            appState.refreshCurrentTab()
        }
    }

    private func trashFolder(_ folderURL: URL) {
        appState.trashWithUndo(urls: [folderURL])
        if appState.currentTab?.currentPath.standardizedFileURL.path
            .hasPrefix(folderURL.standardizedFileURL.path) == true {
            appState.navigate(to: folderURL.deletingLastPathComponent())
        }
        invalidateCache(for: folderURL.deletingLastPathComponent())
        reloadToken += 1
        appState.refreshCurrentTab()
    }

    private func moveFiles(_ urls: [URL], to destination: URL) {
        appState.moveWithUndo(urls: urls, to: destination)
        // Clear selection of moved items to prevent Table state corruption
        let movedIDs = Set(urls.map { $0.absoluteString })
        tab.selectedItems.subtract(movedIDs)
        invalidateCache(for: destination)
        reloadToken += 1
        appState.refreshCurrentTab()
    }

    private func handleDrop(providers: [NSItemProvider], destination: URL) -> Bool {
        let urlProviders = providers.filter { $0.canLoadObject(ofClass: NSURL.self) }
        guard !urlProviders.isEmpty else { return false }

        // Collect all URLs first, then move them together
        var collectedURLs: [URL] = []
        let group = DispatchGroup()
        for provider in urlProviders {
            group.enter()
            _ = provider.loadObject(ofClass: NSURL.self) { reading, _ in
                if let nsurl = reading as? NSURL, let url = nsurl as URL?, url.isFileURL {
                    DispatchQueue.main.async {
                        collectedURLs.append(url)
                        group.leave()
                    }
                } else {
                    DispatchQueue.main.async { group.leave() }
                }
            }
        }
        group.notify(queue: .main) {
            guard !collectedURLs.isEmpty else { return }
            self.moveFiles(collectedURLs, to: destination)
        }
        return true
    }
}

