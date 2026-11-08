import SwiftUI

/// Identifies one directory listing for the folder-size scan's `.task(id:)`.
/// Pairs the path with `itemsGeneration` so a same-folder refresh (e.g. after a
/// delete) is recognized as a new listing, while a mere re-sort of `tab.items`
/// isn't, which would otherwise restart the scan from scratch repeatedly.
private struct FolderScanKey: Equatable {
    let path: URL
    let generation: Int
}

/// Sortable table view displaying directory contents with folders always on top.
struct FileListView: View {
    @Environment(AppState.self) private var appState
    @Bindable var tab: TabState
    @State private var renamingItemID: String?
    @State private var renamingText: String = ""
    @State private var scrollToID: String?

    private var filteredFolders: [FileItem] {
        let query = appState.searchQuery.lowercased()
        let folders = tab.items.filter(\.isDirectory)
        guard !query.isEmpty else { return folders }
        return folders.filter { $0.name.lowercased().contains(query) }
    }

    private var filteredFiles: [FileItem] {
        let query = appState.searchQuery.lowercased()
        let files = tab.items.filter { !$0.isDirectory }
        guard !query.isEmpty else { return files }
        return files.filter { $0.name.lowercased().contains(query) }
    }

    var body: some View {
        Table(of: FileItem.self, selection: Binding(
            get: { tab.selectedItems },
            set: { tab.selectedItems = $0 }
        ), sortOrder: Binding(
            get: { tab.sortOrder },
            set: { newOrder in
                tab.sortOrder = newOrder
                // Column-header clicks arrive through an NSTableView delegate
                // callback; reassigning `tab.items` synchronously from inside it
                // pushes a Table reload back into that same still-executing
                // callback ("reentrant operation" — and it corrupts the table's
                // state for good, not just that one frame). Defer to the next
                // run-loop turn so the callback has already returned.
                DispatchQueue.main.async {
                    sortItems()
                }
            }
        )) {
            TableColumn("Name", sortUsing: KeyPathComparator(\.name)) { item in
                HStack(spacing: 6) {
                    if item.isDirectory {
                        Image(systemName: item.isEmptyFolder ? "folder" : "folder.fill")
                            .foregroundStyle(.secondary)
                            .frame(width: 18, height: 18)
                    } else {
                        Image(nsImage: item.icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 18, height: 18)
                    }

                    Text(item.name)
                        .lineLimit(1)
                        .popover(
                            isPresented: Binding(
                                get: { renamingItemID == item.id },
                                set: { if !$0 { cancelRename() } }
                            ),
                            arrowEdge: .bottom
                        ) {
                            RenamePopoverContent(
                                text: $renamingText,
                                onCommit: { commitRename(item: item) },
                                onCancel: { cancelRename() }
                            )
                        }
                }
            }
            .width(min: 200, ideal: 300)

            TableColumn("Size", sortUsing: KeyPathComparator(\.sizeForSorting)) { item in
                SizeCell(item: item)
                    .foregroundStyle(.secondary)
            }
            .width(min: 60, ideal: 80)

            TableColumn("Date Modified", sortUsing: KeyPathComparator(\.dateModified)) { item in
                Text(item.formattedDate)
                    .foregroundStyle(.secondary)
            }
            .width(min: 120, ideal: 160)

            TableColumn("Kind", sortUsing: KeyPathComparator(\.kind)) { item in
                Text(item.kind)
                    .foregroundStyle(.secondary)
            }
            .width(min: 80, ideal: 120)
        } rows: {
            Section {
                ForEach(filteredFolders) { item in
                    TableRow(item)
                        .itemProvider { NSItemProvider(object: item.url as NSURL) }
                        .contextMenu { fileContextMenu(for: item) }
                }
            }
            Section {
                ForEach(filteredFiles) { item in
                    TableRow(item)
                        .itemProvider { NSItemProvider(object: item.url as NSURL) }
                        .contextMenu { fileContextMenu(for: item) }
                }
            }
        }
        .task(id: FolderScanKey(path: tab.currentPath, generation: tab.itemsGeneration)) {
            await computeFolderSizes()
        }
        .contextMenu {
            backgroundContextMenu()
        }
        .onDeleteCommand {
            let items = selectedFileItems
            guard !items.isEmpty else { return }
            trashAndSelectNext(items)
        }
        .onKeyPress(.return) {
            guard renamingItemID == nil else { return .ignored }
            handleDoubleClick()
            return .handled
        }
        .background(DoubleClickHandler {
            handleDoubleClick()
        })
        .background(TableScrollHelper(scrollToID: $scrollToID, items: filteredFolders + filteredFiles))
        .onChange(of: tab.currentPath) {
            appState.refreshCurrentTab()
            appState.rebuildWatcher()
        }
        .onChange(of: appState.pendingRenameFolder) { _, folderName in
            guard let folderName else { return }
            appState.pendingRenameFolder = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if let item = tab.items.first(where: { $0.name == folderName && $0.isDirectory }) {
                    tab.selectedItems = [item.id]
                    scrollToID = item.id
                    renamingText = folderName
                    renamingItemID = item.id
                }
            }
        }
        .onChange(of: appState.scrollToItemID) { _, itemID in
            guard let itemID else { return }
            appState.scrollToItemID = nil
            scrollToID = itemID
        }
    }

    // MARK: - Rename

    private func startRename(item: FileItem) {
        renamingText = item.name
        renamingItemID = item.id
    }

    private func cancelRename() {
        renamingItemID = nil
        renamingText = ""
    }

    private func commitRename(item: FileItem) {
        let newName = renamingText.trimmingCharacters(in: .whitespaces)
        renamingItemID = nil
        guard !newName.isEmpty, newName != item.name else { return }

        appState.renameWithUndo(at: item.url, to: newName)
        appState.refreshCurrentTab()
    }

    // MARK: - New Folder (inline)

    private func createNewFolder(in parent: URL) {
        let baseName = "New Folder"
        var name = baseName
        var counter = 1
        while FileManager.default.fileExists(atPath: parent.appendingPathComponent(name).path) {
            counter += 1
            name = "\(baseName) \(counter)"
        }

        guard appState.createFolderWithUndo(at: parent, name: name) != nil else { return }
        appState.refreshCurrentTab()

        // Find the new folder in refreshed items by matching the name and parent
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if let newItem = tab.items.first(where: { $0.name == name && $0.isDirectory }) {
                tab.selectedItems = [newItem.id]
                scrollToID = newItem.id
                renamingText = name
                renamingItemID = newItem.id
            }
        }
    }

    // MARK: - Sorting

    private func sortItems() {
        let order = tab.sortOrder
        var folders = tab.items.filter(\.isDirectory)
        var files = tab.items.filter { !$0.isDirectory }
        folders.sort(using: order)
        files.sort(using: order)
        tab.items = folders + files
    }

    // MARK: - Folder sizes

    /// Computes every subfolder's recursive content size for the current directory,
    /// regardless of which rows are on screen, so they're known once (for sorting
    /// by size) and never recomputed just from scrolling. Tied to `tab.currentPath`:
    /// cancelled when navigating away, and starts fresh on return since the folder's
    /// contents may have changed since.
    ///
    /// Scanned with bounded concurrency rather than one at a time: a single huge
    /// folder (e.g. a cache directory with hundreds of thousands of files) would
    /// otherwise block every folder listed after it from ever getting a size.
    private func computeFolderSizes() async {
        let service = appState.fileService
        let showHidden = appState.showHiddenFiles
        let folders = tab.items.filter { $0.usesFolderSize && $0.folderSize == nil }
        guard !folders.isEmpty else { return }

        // Reassigning `tab.items` is what makes the Table redraw — but doing
        // that repeatedly (even coalesced to a few times a second) collided
        // with AppKit's own internal NSTableView update/layout machinery
        // ("reentrant operation" warning), which corrupted the table's
        // rendering state until the app was restarted — not something a
        // longer delay fixed, just something a lower rate made rarer. So
        // `tab.items` is touched exactly once here, after every size is
        // known; individual FileItem properties are still updated live as
        // each scan finishes, which SwiftUI's Observation tracking reflects
        // in already-visible cells without needing the array itself to change.
        let maxConcurrentScans = 4
        await withTaskGroup(of: Void.self) { group in
            var remaining = folders.makeIterator()

            func scanNext() {
                guard let folder = remaining.next() else { return }
                group.addTask { @MainActor in
                    guard !Task.isCancelled else { return }
                    folder.isComputingFolderSize = true
                    let url = folder.url
                    // DispatchQueue.global work is invisible to Swift's cancellation
                    // machinery, so without this bridge a scan for a folder the user
                    // has already left keeps running to completion in the background,
                    // competing with the scan for whatever folder is open now.
                    let cancelFlag = CancelFlag()
                    let result = await withTaskCancellationHandler {
                        await withCheckedContinuation { (continuation: CheckedContinuation<(fileCount: Int, totalSize: Int64), Never>) in
                            DispatchQueue.global(qos: .utility).async {
                                continuation.resume(returning: service.folderStatistics(
                                    at: url, showHidden: showHidden, isCancelled: { cancelFlag.isCancelled }
                                ))
                            }
                        }
                    } onCancel: {
                        cancelFlag.cancel()
                    }
                    guard !Task.isCancelled else { return }
                    folder.folderSize = result.totalSize
                    folder.isComputingFolderSize = false
                }
            }

            for _ in 0..<maxConcurrentScans { scanNext() }
            for await _ in group { scanNext() }
        }
        sortItems()
    }

    private var selectedFileItems: [FileItem] {
        tab.items.filter { tab.selectedItems.contains($0.id) }
    }

    private func handleDoubleClick() {
        guard renamingItemID == nil else { return }
        let selected = selectedFileItems
        guard selected.count == 1, let item = selected.first else { return }

        if item.isDirectory {
            appState.navigate(to: item.url)
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }

    // MARK: - Copy & Paste

    private func trashAndSelectNext(_ items: [FileItem]) {
        let allItems = filteredFolders + filteredFiles
        let deletedIDs = Set(items.map(\.id))
        var nextName: String?
        if let lastIndex = allItems.lastIndex(where: { deletedIDs.contains($0.id) }) {
            if lastIndex + 1 < allItems.count, !deletedIDs.contains(allItems[lastIndex + 1].id) {
                nextName = allItems[lastIndex + 1].name
            } else if let prev = allItems[0...lastIndex].last(where: { !deletedIDs.contains($0.id) }) {
                nextName = prev.name
            }
        }

        // Check for non-empty folders
        let nonEmptyFolders = items.filter { $0.isDirectory && !appState.fileService.isDirectoryEmpty($0.url) }
        if !nonEmptyFolders.isEmpty {
            let alert = NSAlert()
            alert.messageText = "Move to Trash?"
            if nonEmptyFolders.count == 1 {
                alert.informativeText = "\"\(nonEmptyFolders[0].name)\" is not empty. Are you sure?"
            } else {
                alert.informativeText = "\(nonEmptyFolders.count) folders are not empty. Are you sure?"
            }
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Move to Trash")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }

        appState.trashWithUndo(urls: items.map(\.url))
        appState.refreshCurrentTab()
        if let nextName {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if let item = tab.items.first(where: { $0.name == nextName }) {
                    tab.selectedItems = [item.id]
                    scrollToID = item.id
                }
            }
        }
    }

    private func pasteFiles() {
        guard let urls = NSPasteboard.general.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL], !urls.isEmpty else { return }
        let dest = tab.currentPath
        let pastedURLs = appState.pasteWithUndo(urls: urls, to: dest)
        appState.refreshCurrentTab()
        if let lastURL = pastedURLs.last {
            let pastedNames = pastedURLs.map(\.lastPathComponent)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if let item = tab.items.first(where: { $0.name == lastURL.lastPathComponent }) {
                    tab.selectedItems = Set(tab.items.filter { pastedNames.contains($0.name) }.map(\.id))
                    scrollToID = item.id
                }
            }
        }
    }

    // MARK: - Context Menus

    @ViewBuilder
    private func backgroundContextMenu() -> some View {
        Button("New Folder") {
            createNewFolder(in: tab.currentPath)
        }

        Button("Paste") {
            pasteFiles()
        }

        Divider()

        Button("Refresh") {
            appState.refreshCurrentTab()
        }
    }

    @ViewBuilder
    private func fileContextMenu(for item: FileItem) -> some View {
        let items = tab.selectedItems.contains(item.id) ? selectedFileItems : [item]
        let isSingle = items.count == 1

        if isSingle {
            Button("Open") {
                if item.isDirectory {
                    appState.navigate(to: item.url)
                } else {
                    NSWorkspace.shared.open(item.url)
                }
            }

            Button("Open in New Tab") {
                appState.addTab(path: item.url)
            }
            .disabled(!item.isDirectory)

            Divider()

            Button("Rename") {
                startRename(item: item)
            }
        } else {
            Button("Open All (\(items.count) items)") {
                for f in items {
                    if f.isDirectory {
                        appState.addTab(path: f.url)
                    } else {
                        NSWorkspace.shared.open(f.url)
                    }
                }
            }
        }

        Divider()

        if isSingle && item.isDirectory {
            Button("New Folder in \"\(item.name)\"") {
                createNewFolder(in: item.url)
            }

            Divider()
        }

        Button("New Folder Here") {
            createNewFolder(in: tab.currentPath)
        }

        Divider()

        Button("Copy") {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.writeObjects(items.map(\.url) as [NSURL])
        }

        Button("Paste") {
            pasteFiles()
        }

        Divider()

        Button("Show in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting(items.map(\.url))
        }

        Divider()

        Button("Move to Trash (\(items.count) item\(items.count == 1 ? "" : "s"))", role: .destructive) {
            trashAndSelectNext(items)
        }
    }
}

/// Shows a file's size, or a folder's recursive content size once
/// `FileListView.computeFolderSizes()` has filled it in.
struct SizeCell: View {
    let item: FileItem

    var body: some View {
        if item.usesFolderSize && item.isComputingFolderSize {
            ProgressView().controlSize(.mini)
        } else {
            Text(item.formattedSize)
        }
    }
}

/// Popover content for renaming a file or folder.
struct RenamePopoverContent: View {
    @Binding var text: String
    let onCommit: () -> Void
    let onCancel: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text("Rename")
                .font(.headline)
            TextField("Name", text: $text)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onSubmit { onCommit() }
                .onExitCommand { onCancel() }
                .frame(minWidth: 250)
        }
        .padding(12)
        .onAppear {
            isFocused = true
        }
    }
}

/// Scrolls the enclosing NSTableView to show a specific item by ID.
struct TableScrollHelper: NSViewRepresentable {
    @Binding var scrollToID: String?
    let items: [FileItem]

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let targetID = scrollToID else { return }
        DispatchQueue.main.async {
            self.scrollToID = nil
            guard let rowIndex = items.firstIndex(where: { $0.id == targetID }) else { return }
            guard let tableView = findTableView(from: nsView) else { return }
            tableView.scrollRowToVisible(rowIndex)
        }
    }

    private func findTableView(from view: NSView) -> NSTableView? {
        var current: NSView? = view
        while let v = current {
            if let table = v as? NSTableView { return table }
            if let found = v.subviewsRecursive().first(where: { $0 is NSTableView }) as? NSTableView {
                return found
            }
            current = v.superview
        }
        return nil
    }
}

/// Finds the enclosing NSTableView and installs a doubleAction handler.
struct DoubleClickHandler: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = DoubleClickListenerView()
        view.onDoubleClick = action
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? DoubleClickListenerView)?.onDoubleClick = action
    }
}

private class DoubleClickListenerView: NSView {
    var onDoubleClick: (() -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let tableView = self.findTableView(in: self) {
                tableView.target = self
                tableView.doubleAction = #selector(self.handleDoubleClick)
            }
        }
    }

    private func findTableView(in view: NSView) -> NSTableView? {
        var current: NSView? = view
        while let v = current {
            if let table = v as? NSTableView { return table }
            if let found = v.subviewsRecursive().first(where: { $0 is NSTableView }) as? NSTableView {
                return found
            }
            current = v.superview
        }
        return nil
    }

    @objc private func handleDoubleClick() {
        onDoubleClick?()
    }
}

extension NSView {
    func subviewsRecursive() -> [NSView] {
        subviews + subviews.flatMap { $0.subviewsRecursive() }
    }
}
