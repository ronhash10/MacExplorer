import SwiftUI

/// Sortable table view displaying directory contents.
struct FileListView: View {
    @Environment(AppState.self) private var appState
    @Bindable var tab: TabState

    var body: some View {
        Table(of: FileItem.self, selection: Binding(
            get: { tab.selectedItems },
            set: { tab.selectedItems = $0 }
        ), sortOrder: Binding(
            get: { tab.sortOrder },
            set: { newOrder in
                tab.sortOrder = newOrder
                tab.items.sort(using: newOrder)
            }
        )) {
            TableColumn("Name", sortUsing: KeyPathComparator(\.name)) { item in
                HStack(spacing: 6) {
                    Image(nsImage: item.icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                    Text(item.name)
                        .lineLimit(1)
                }
            }
            .width(min: 200, ideal: 300)

            TableColumn("Size", sortUsing: KeyPathComparator(\.size)) { item in
                Text(item.formattedSize)
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
            ForEach(filteredItems) { item in
                TableRow(item)
                    .contextMenu {
                        fileContextMenu(for: item)
                    }
            }
        }
        .background(DoubleClickHandler {
            handleDoubleClick()
        })
        .onChange(of: tab.currentPath) {
            appState.refreshCurrentTab()
        }
    }

    private var filteredItems: [FileItem] {
        let query = appState.searchQuery.lowercased()
        guard !query.isEmpty else { return tab.items }
        return tab.items.filter { $0.name.lowercased().contains(query) }
    }

    private var selectedFileItems: [FileItem] {
        tab.items.filter { tab.selectedItems.contains($0.id) }
    }

    private func handleDoubleClick() {
        let selected = selectedFileItems
        guard selected.count == 1, let item = selected.first else { return }

        if item.isDirectory {
            appState.navigate(to: item.url)
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }

    @ViewBuilder
    private func fileContextMenu(for item: FileItem) -> some View {
        // Use the full selection if the right-clicked item is part of it,
        // otherwise treat it as a single-item action.
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

        Button("Show in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting(items.map(\.url))
        }

        Divider()

        Button("Move to Trash (\(items.count) item\(items.count == 1 ? "" : "s"))", role: .destructive) {
            for f in items {
                try? appState.fileService.moveToTrash(f.url)
            }
            appState.refreshCurrentTab()
        }
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
        // Walk up the view hierarchy to find the NSTableView and set its doubleAction
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let tableView = self.findTableView(in: self) {
                tableView.target = self
                tableView.doubleAction = #selector(self.handleDoubleClick)
            }
        }
    }

    private func findTableView(in view: NSView) -> NSTableView? {
        // Search up through superviews
        var current: NSView? = view
        while let v = current {
            if let table = v as? NSTableView { return table }
            // Also search siblings/children of ancestors
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

private extension NSView {
    func subviewsRecursive() -> [NSView] {
        subviews + subviews.flatMap { $0.subviewsRecursive() }
    }
}
