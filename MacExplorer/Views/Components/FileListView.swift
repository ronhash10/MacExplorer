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
        .onDoubleClick {
            handleDoubleClick()
        }
        .onChange(of: tab.currentPath) {
            appState.refreshCurrentTab()
        }
    }

    private var filteredItems: [FileItem] {
        let query = appState.searchQuery.lowercased()
        guard !query.isEmpty else { return tab.items }
        return tab.items.filter { $0.name.lowercased().contains(query) }
    }

    private func handleDoubleClick() {
        guard let selectedID = tab.selectedItems.first,
              let item = tab.items.first(where: { $0.id == selectedID }) else { return }

        if item.isDirectory {
            appState.navigate(to: item.url)
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }

    @ViewBuilder
    private func fileContextMenu(for item: FileItem) -> some View {
        Button("Open") {
            if item.isDirectory {
                appState.navigate(to: item.url)
            } else {
                NSWorkspace.shared.open(item.url)
            }
        }

        Button("Open in New Tab") {
            if item.isDirectory {
                appState.addTab(path: item.url)
            }
        }
        .disabled(!item.isDirectory)

        Divider()

        Button("Show in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([item.url])
        }

        Divider()

        Button("Move to Trash", role: .destructive) {
            try? appState.fileService.moveToTrash(item.url)
            appState.refreshCurrentTab()
        }
    }
}

// Double-click support for SwiftUI Table via NSView introspection.
struct OnDoubleClickModifier: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content.onTapGesture(count: 2, perform: action)
    }
}

extension View {
    func onDoubleClick(perform action: @escaping () -> Void) -> some View {
        modifier(OnDoubleClickModifier(action: action))
    }
}
