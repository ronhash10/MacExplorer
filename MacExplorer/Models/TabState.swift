import Foundation
import SwiftUI

/// Represents a single tab's navigation state.
@Observable
final class TabState: Identifiable {
    let id: UUID
    var title: String
    var currentPath: URL
    var selectedItems: Set<FileItem.ID> = []
    var items: [FileItem] = []
    var sortOrder: [KeyPathComparator<FileItem>] = [
        KeyPathComparator(\.name, order: .forward)
    ]

    // Search tab properties
    var isSearchTab: Bool = false
    var searchQuery: String?
    var searchRootPath: URL?
    var isSearching: Bool = false

    private var backStack: [URL] = []
    private var forwardStack: [URL] = []

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }

    init(path: URL? = nil) {
        self.id = UUID()
        let startPath = path ?? FileManager.default.homeDirectoryForCurrentUser
        self.currentPath = startPath
        self.title = startPath.lastPathComponent
    }

    /// Create a search tab.
    init(searchQuery: String, rootPath: URL) {
        self.id = UUID()
        self.isSearchTab = true
        self.searchQuery = searchQuery
        self.searchRootPath = rootPath
        self.currentPath = rootPath
        self.title = "\"\(searchQuery)\" in \(rootPath.lastPathComponent)"
        self.isSearching = true
    }

    func navigate(to url: URL) {
        guard url != currentPath else { return }
        backStack.append(currentPath)
        forwardStack.removeAll()
        currentPath = url
        title = url.lastPathComponent
        selectedItems.removeAll()
    }

    func goBack() {
        guard let previous = backStack.popLast() else { return }
        forwardStack.append(currentPath)
        currentPath = previous
        title = previous.lastPathComponent
        selectedItems.removeAll()
    }

    func goForward() {
        guard let next = forwardStack.popLast() else { return }
        backStack.append(currentPath)
        currentPath = next
        title = next.lastPathComponent
        selectedItems.removeAll()
    }

    /// Path components for breadcrumb display.
    var pathComponents: [(name: String, url: URL)] {
        var components: [(String, URL)] = []
        var url = currentPath
        while url.path != "/" {
            components.insert((url.lastPathComponent, url), at: 0)
            url = url.deletingLastPathComponent()
        }
        components.insert(("/", URL(fileURLWithPath: "/")), at: 0)
        return components
    }
}
