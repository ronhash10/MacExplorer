import Foundation
import SwiftUI

/// Global singleton managing all explorer windows and enabling cross-window tab transfer.
@Observable
final class WindowManager {
    static let shared = WindowManager()

    private(set) var windowStates: [UUID: AppState] = [:]

    private init() {}

    /// Register a new window's AppState and return its window ID.
    @discardableResult
    func register(_ appState: AppState) -> UUID {
        let id = appState.windowID
        windowStates[id] = appState
        return id
    }

    /// Unregister a window when it closes.
    func unregister(_ id: UUID) {
        windowStates.removeValue(forKey: id)
    }

    /// Transfer a tab from one window to another.
    func transferTab(tabID: UUID, fromWindow sourceID: UUID, toWindow targetID: UUID, atIndex insertIndex: Int? = nil) {
        guard sourceID != targetID,
              let source = windowStates[sourceID],
              let target = windowStates[targetID],
              let tabIndex = source.tabs.firstIndex(where: { $0.id == tabID }) else { return }

        let tab = source.tabs.remove(at: tabIndex)

        if let insertIndex, target.tabs.indices.contains(insertIndex) || insertIndex == target.tabs.count {
            target.tabs.insert(tab, at: insertIndex)
        } else {
            target.tabs.append(tab)
        }

        target.activeTabID = tab.id
        target.refreshCurrentTab()

        // Update source's active tab if needed
        if source.activeTabID == tabID {
            source.activeTabID = source.tabs.last?.id
            source.refreshCurrentTab()
        }

        // If source window has no tabs, mark it for closing
        if source.tabs.isEmpty {
            source.shouldClose = true
        }
    }
}
