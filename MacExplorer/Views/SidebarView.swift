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

    /// Flatten the tree: only include children of expanded nodes
    private var visibleNodes: [FlatNode] {
        // Access reloadToken to trigger recomputation
        _ = reloadToken
        var result: [FlatNode] = []
        func visit(_ url: URL, depth: Int) {
            let stdPath = url.standardizedFileURL.path
            let children = loadChildren(of: url)
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

    private func loadChildren(of url: URL) -> [URL] {
        appState.fileService.contentsOfDirectory(at: url)
            .filter(\.isDirectory)
            .map(\.url)
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    /// Ensure all ancestors of a path are expanded
    private func expandAncestors(of targetURL: URL) {
        let rootPath = treeRoot.standardizedFileURL.path
        let targetPath = targetURL.standardizedFileURL.path
        guard targetPath.hasPrefix(rootPath) else { return }

        // Walk from root to target, expanding each ancestor
        var current = treeRoot.standardizedFileURL
        expandedPaths.insert(current.path)
        let rootComponents = treeRoot.standardizedFileURL.pathComponents
        let targetComponents = targetURL.standardizedFileURL.pathComponents
        for i in rootComponents.count..<targetComponents.count {
            current = current.appendingPathComponent(targetComponents[i])
            expandedPaths.insert(current.standardizedFileURL.path)
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
                        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
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

                    // MARK: Folders tree (VStack, not LazyVStack, so ScrollViewReader can find all IDs)
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
            }
            .onChange(of: tab.currentPath) {
                expandAncestors(of: tab.currentPath)
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
            // No chevron for non-tree items
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
                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
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
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
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
            Button("Move to Trash", role: .destructive) { trashFolder(node.url) }
        }
    }

    // MARK: - Actions

    private func commitRename(from oldURL: URL) {
        renamingURL = nil
        let newName = renameText.trimmingCharacters(in: .whitespaces)
        guard !newName.isEmpty, newName != oldURL.lastPathComponent else { return }
        let newURL = oldURL.deletingLastPathComponent().appendingPathComponent(newName, isDirectory: true)
        try? FileManager.default.moveItem(at: oldURL, to: newURL)

        // Update expanded paths: replace old path with new
        let oldPath = oldURL.standardizedFileURL.path
        let newPath = newURL.standardizedFileURL.path
        let pathsToUpdate = expandedPaths.filter { $0.hasPrefix(oldPath) }
        for path in pathsToUpdate {
            expandedPaths.remove(path)
            expandedPaths.insert(path.replacingOccurrences(of: oldPath, with: newPath))
        }

        // Force reload of tree data
        reloadToken += 1

        appState.navigate(to: newURL.standardizedFileURL)
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
        _ = try? appState.fileService.createFolder(at: parentURL, name: name)
        // Force reload of tree
        reloadToken += 1
        // Ensure parent is expanded
        expandedPaths.insert(parentURL.standardizedFileURL.path)
        appState.navigate(to: parentURL)
        appState.pendingRenameFolder = name
    }

    private func trashFolder(_ folderURL: URL) {
        TrashHelper.moveToTrash([folderURL], using: appState.fileService) {
            if appState.currentTab?.currentPath.standardizedFileURL.path
                .hasPrefix(folderURL.standardizedFileURL.path) == true {
                appState.navigate(to: folderURL.deletingLastPathComponent())
            }
            reloadToken += 1
            appState.refreshCurrentTab()
        }
    }

    private func moveFiles(_ urls: [URL], to destination: URL) {
        for url in urls {
            let target = destination.appendingPathComponent(url.lastPathComponent)
            guard url.deletingLastPathComponent().standardizedFileURL != destination.standardizedFileURL else { continue }
            try? FileManager.default.moveItem(at: url, to: target)
        }
        reloadToken += 1
        appState.refreshCurrentTab()
    }

    private func handleDrop(providers: [NSItemProvider], destination: URL) -> Bool {
        var handled = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                handled = true
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                    guard let data = data as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil, isAbsolute: true) else { return }
                    DispatchQueue.main.async {
                        moveFiles([url], to: destination)
                    }
                }
            }
        }
        return handled
    }
}

