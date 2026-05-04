import SwiftUI

/// Bottom status bar showing item count and selection info.
struct StatusBar: View {
    @Environment(AppState.self) private var appState
    let tab: TabState

    private var displayedItems: [FileItem] {
        let query = appState.searchQuery.lowercased()
        guard !query.isEmpty else { return tab.items }
        return tab.items.filter { $0.name.lowercased().contains(query) }
    }

    var body: some View {
        HStack {
            let items = displayedItems
            let total = items.count
            let selected = tab.selectedItems.count

            if !appState.searchQuery.isEmpty {
                Text("\(total) of \(tab.items.count) item\(tab.items.count == 1 ? "" : "s")")
            } else {
                Text("\(total) item\(total == 1 ? "" : "s")")
            }

            if selected > 0 {
                Text("·")
                    .foregroundStyle(.tertiary)
                Text("\(selected) selected")
            }

            Spacer()

            let totalSize = items
                .filter { !$0.isDirectory }
                .reduce(Int64(0)) { $0 + $1.size }
            Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(.bar)
    }
}
