import Foundation
import SwiftUI

/// Top-level application state managing tabs and global preferences.
@Observable
final class AppState {
    let windowID = UUID()
    var tabs: [TabState] = []
    var activeTabID: UUID?
    var showPreview: Bool = true
    var showHiddenFiles: Bool = false
    var searchQuery: String = ""
    var shouldClose: Bool = false

    let fileService = FileSystemService()

    var currentTab: TabState? {
        get { tabs.first { $0.id == activeTabID } }
        set {
            if let tab = newValue {
                activeTabID = tab.id
            }
        }
    }

    init() {
        addTab()
    }

    @discardableResult
    func addTab(path: URL? = nil) -> TabState {
        let tab = TabState(path: path)
        tabs.append(tab)
        activeTabID = tab.id
        refreshCurrentTab()
        return tab
    }

    func closeTab(_ id: UUID) {
        guard tabs.count > 0 else { return }
        if let index = tabs.firstIndex(where: { $0.id == id }) {
            tabs.remove(at: index)
            if activeTabID == id {
                // Activate the nearest tab
                let newIndex = min(index, tabs.count - 1)
                activeTabID = tabs.indices.contains(newIndex) ? tabs[newIndex].id : nil
            }
        }
    }

    func closeCurrentTab() {
        guard let id = activeTabID else { return }
        closeTab(id)
    }

    func refreshCurrentTab() {
        guard let tab = currentTab else { return }
        tab.items = fileService.contentsOfDirectory(
            at: tab.currentPath,
            showHidden: showHiddenFiles
        )
    }

    func navigate(to url: URL) {
        guard let tab = currentTab else { return }
        tab.navigate(to: url)
        refreshCurrentTab()
    }
}
