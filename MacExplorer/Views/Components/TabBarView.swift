import SwiftUI

/// Tab bar showing all open tabs with add/close controls.
struct TabBarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 1) {
                    ForEach(appState.tabs) { tab in
                        TabItemView(
                            tab: tab,
                            isActive: tab.id == appState.activeTabID,
                            onSelect: {
                                appState.activeTabID = tab.id
                                appState.refreshCurrentTab()
                            },
                            onClose: {
                                appState.closeTab(tab.id)
                            }
                        )
                    }
                }
            }

            Spacer()

            Button(action: { appState.addTab() }) {
                Image(systemName: "plus")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 4)
        .padding(.leading, 4)
        .background(.bar)
    }
}

/// Individual tab button.
struct TabItemView: View {
    let tab: TabState
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "folder")
                .font(.caption2)
            Text(tab.title)
                .lineLimit(1)
                .font(.callout)
                .frame(maxWidth: 140)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .opacity(isHovering || isActive ? 1 : 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? Color.accentColor.opacity(0.15) : (isHovering ? Color.gray.opacity(0.1) : Color.clear))
        )
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
