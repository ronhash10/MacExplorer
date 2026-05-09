import SwiftUI

/// Displays search results in a table with Name, Location, Size, and Date columns.
struct SearchResultsView: View {
    @Environment(AppState.self) private var appState
    @Bindable var tab: TabState

    private var sortedItems: [FileItem] {
        tab.items.sorted(using: tab.sortOrder)
    }

    var body: some View {
        VStack(spacing: 0) {
            if tab.isSearching {
                Spacer()
                ProgressView("Searching…")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Spacer()
            } else if tab.items.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("No results found")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("for \"\(tab.searchQuery ?? "")\" in \(tab.searchRootPath?.lastPathComponent ?? "")")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            } else {
                resultsTable
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var resultsTable: some View {
        Table(of: FileItem.self, selection: Binding(
            get: { tab.selectedItems },
            set: { tab.selectedItems = $0 }
        ), sortOrder: Binding(
            get: { tab.sortOrder },
            set: { newOrder in
                tab.sortOrder = newOrder
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
                }
            }
            .width(min: 180, ideal: 250)

            TableColumn("Location") { item in
                Text(relativePath(for: item))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help(item.url.deletingLastPathComponent().path)
            }
            .width(min: 150, ideal: 250)

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
        } rows: {
            ForEach(sortedItems) { item in
                TableRow(item)
                    .contextMenu { searchContextMenu(for: item) }
            }
        }
        .background(DoubleClickHandler {
            handleDoubleClick()
        })
    }

    private func relativePath(for item: FileItem) -> String {
        guard let root = tab.searchRootPath else { return item.url.deletingLastPathComponent().path }
        let parentPath = item.url.deletingLastPathComponent().path
        let rootPath = root.path
        if parentPath == rootPath { return "/" }
        if parentPath.hasPrefix(rootPath) {
            let relative = String(parentPath.dropFirst(rootPath.count))
            return relative.hasPrefix("/") ? relative : "/\(relative)"
        }
        return parentPath
    }

    @ViewBuilder
    private func searchContextMenu(for item: FileItem) -> some View {
        Button("Open") {
            NSWorkspace.shared.open(item.url)
        }

        Button("Open Containing Folder") {
            let parentFolder = item.url.deletingLastPathComponent()
            appState.addTab(path: parentFolder)
        }

        Divider()

        Button("Reveal in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([item.url])
        }

        Button("Copy Path") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(item.url.path, forType: .string)
        }
    }

    private func handleDoubleClick() {
        guard let selectedID = tab.selectedItems.first,
              let item = tab.items.first(where: { $0.id == selectedID }) else { return }

        if item.isDirectory {
            appState.addTab(path: item.url)
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }
}
