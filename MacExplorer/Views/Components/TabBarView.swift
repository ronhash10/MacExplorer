import SwiftUI

/// Tab bar showing all open tabs with add/close controls and drag-to-merge support.
struct TabBarView: View {
    @Environment(AppState.self) private var appState
    @State private var dragOverIndex: Int?

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 1) {
                    ForEach(Array(appState.tabs.enumerated()), id: \.element.id) { index, tab in
                        TabItemView(
                            tab: tab,
                            isActive: tab.id == appState.activeTabID,
                            isDragTarget: dragOverIndex == index,
                            windowID: appState.windowID,
                            onSelect: {
                                appState.activeTabID = tab.id
                                appState.refreshCurrentTab()
                            },
                            onClose: {
                                appState.closeTab(tab.id)
                            }
                        )
                        .dropDestination(for: TabTransferData.self) { items, _ in
                            handleDrop(items, atIndex: index)
                        } isTargeted: { targeted in
                            dragOverIndex = targeted ? index : nil
                        }
                    }
                }
            }
            // Drop zone at the end of the tab bar (append)
            .dropDestination(for: TabTransferData.self) { items, _ in
                handleDrop(items, atIndex: appState.tabs.count)
            } isTargeted: { _ in }

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

    private func handleDrop(_ items: [TabTransferData], atIndex index: Int) -> Bool {
        guard let data = items.first,
              let tabID = data.tabUUID,
              let sourceWindowID = data.windowUUID else { return false }

        let targetWindowID = appState.windowID

        if sourceWindowID == targetWindowID {
            // Reorder within the same window
            guard let fromIndex = appState.tabs.firstIndex(where: { $0.id == tabID }),
                  fromIndex != index else { return false }
            let tab = appState.tabs.remove(at: fromIndex)
            let adjustedIndex = min(index, appState.tabs.count)
            appState.tabs.insert(tab, at: adjustedIndex)
            appState.activeTabID = tab.id
            return true
        } else {
            // Transfer from another window
            WindowManager.shared.transferTab(
                tabID: tabID,
                fromWindow: sourceWindowID,
                toWindow: targetWindowID,
                atIndex: index
            )
            return true
        }
    }
}

/// Individual tab button with drag support.
struct TabItemView: View {
    let tab: TabState
    let isActive: Bool
    let isDragTarget: Bool
    let windowID: UUID
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
            .focusable(false)
            .opacity(isHovering || isActive ? 1 : 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isDragTarget ? Color.accentColor.opacity(0.3) :
                      isActive ? Color.accentColor.opacity(0.15) :
                      (isHovering ? Color.gray.opacity(0.1) : Color.clear))
        )
        .overlay(
            isDragTarget ?
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.accentColor, lineWidth: 2)
                : nil
        )
        .onTapGesture(perform: onSelect)
        .focusable(false)
        .onHover { hovering in
            isHovering = hovering
        }
        .draggable(TabTransferData(tab: tab, windowID: windowID)) {
            // Drag preview
            HStack(spacing: 4) {
                Image(systemName: "folder")
                    .font(.caption2)
                Text(tab.title)
                    .font(.callout)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.2))
            )
        }
    }
}
