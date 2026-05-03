import SwiftUI

/// Bottom status bar showing item count and selection info.
struct StatusBar: View {
    @Environment(AppState.self) private var appState
    let tab: TabState

    var body: some View {
        HStack {
            let total = tab.items.count
            let selected = tab.selectedItems.count

            Text("\(total) item\(total == 1 ? "" : "s")")

            if selected > 0 {
                Text("·")
                    .foregroundStyle(.tertiary)
                Text("\(selected) selected")
            }

            Spacer()

            let totalSize = tab.items
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
