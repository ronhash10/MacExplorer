import SwiftUI

/// Tab bar showing all open tabs with add/close controls and drag-to-merge support.
struct TabBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var dragOverIndex: Int?
    @State private var isAddHovered = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab bar background (slightly darker than content)
            Color(nsColor: .windowBackgroundColor)
                .opacity(colorScheme == .dark ? 1 : 0.6)

            // Bottom separator line (full width)
            VStack {
                Spacer()
                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(height: 1)
            }

            // Tabs content
            HStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(Array(appState.tabs.enumerated()), id: \.element.id) { index, tab in
                            let isActive = tab.id == appState.activeTabID

                            if index > 0 && !isActive && appState.tabs[safe: index - 1]?.id != appState.activeTabID {
                                // Divider between inactive tabs
                                Rectangle()
                                    .fill(Color(nsColor: .separatorColor))
                                    .frame(width: 1, height: 16)
                                    .padding(.vertical, 6)
                            }

                            TabItemView(
                                tab: tab,
                                isActive: isActive,
                                isDragTarget: dragOverIndex == index,
                                windowID: appState.windowID,
                                onSelect: {
                                    appState.activeTabID = tab.id
                                    // Refresh in background to catch filesystem changes
                                    DispatchQueue.main.async {
                                        appState.refreshCurrentTab()
                                        appState.rebuildWatcher()
                                    }
                                },
                                onClose: {
                                    appState.closeTab(tab.id)
                                }
                            )
                            .zIndex(isActive ? 1 : 0)
                            .dropDestination(for: TabTransferData.self) { items, _ in
                                handleDrop(items, atIndex: index)
                            } isTargeted: { targeted in
                                dragOverIndex = targeted ? index : nil
                            }
                        }

                        // + button inline after last tab
                        Button(action: { appState.addTab() }) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 26, height: 26)
                                .background(
                                    Circle()
                                        .fill(Color.primary.opacity(isAddHovered ? 0.10 : 0))
                                )
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .onHover { isAddHovered = $0 }
                        .padding(.leading, 8)
                    }
                    .padding(.horizontal, 4)
                }
                .dropDestination(for: TabTransferData.self) { items, _ in
                    handleDrop(items, atIndex: appState.tabs.count)
                } isTargeted: { _ in }

                Spacer()
            }
            .padding(.top, 4)
        }
        .frame(height: 36)
    }

    private func handleDrop(_ items: [TabTransferData], atIndex index: Int) -> Bool {
        guard let data = items.first,
              let tabID = data.tabUUID,
              let sourceWindowID = data.windowUUID else { return false }

        let targetWindowID = appState.windowID

        if sourceWindowID == targetWindowID {
            guard let fromIndex = appState.tabs.firstIndex(where: { $0.id == tabID }),
                  fromIndex != index else { return false }
            let tab = appState.tabs.remove(at: fromIndex)
            let adjustedIndex = min(index, appState.tabs.count)
            appState.tabs.insert(tab, at: adjustedIndex)
            appState.activeTabID = tab.id
            return true
        } else {
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

/// Individual tab button with Safari/Chrome connected style.
struct TabItemView: View {
    let tab: TabState
    let isActive: Bool
    let isDragTarget: Bool
    let windowID: UUID
    let onSelect: () -> Void
    let onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false
    @State private var isHoveringClose = false

    private let tabHeight: CGFloat = 30

    private var activeTabShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 8,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: 8
        )
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: tab.isSearchTab ? "magnifyingglass" : "folder")
                .font(.system(size: 12))
                .foregroundStyle(isActive ? Color.accentColor : .secondary)

            Text(tab.title)
                .lineLimit(1)
                .font(.system(size: 12))
                .foregroundStyle(isActive ? .primary : .secondary)
                .frame(maxWidth: 140)

            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(isHoveringClose ? .primary : .secondary)
                    .frame(width: 18, height: 18)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.primary.opacity(isHoveringClose ? 0.12 : 0))
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .onHover { isHoveringClose = $0 }
            .opacity(isHovering || isActive ? 1 : 0)
            .animation(.easeInOut(duration: 0.1), value: isHovering)
        }
        .padding(.horizontal, 12)
        .frame(height: tabHeight)
        .background {
            if isActive {
                activeTabShape
                    .fill(Color(nsColor: .controlBackgroundColor))
                activeTabShape
                    .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.08 : 0.04))
            } else if isDragTarget {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.15))
                    .padding(.bottom, 2)
            } else if isHovering {
                UnevenRoundedRectangle(
                    topLeadingRadius: 6,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 6
                )
                .fill(Color.primary.opacity(0.05))
            }
        }
        .overlay(
            isDragTarget ?
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.accentColor, lineWidth: 2)
                    .padding(.bottom, 2)
                : nil
        )
        .onTapGesture(perform: onSelect)
        .focusable(false)
        .onHover { hovering in
            isHovering = hovering
        }
        .draggable(TabTransferData(tab: tab, windowID: windowID)) {
            HStack(spacing: 4) {
                Image(systemName: "folder")
                    .font(.system(size: 12))
                Text(tab.title)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.2))
            )
        }
    }
}

// Safe array subscript
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
