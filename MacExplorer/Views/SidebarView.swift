import SwiftUI

/// Sidebar folder tree with quick-access locations and expandable directories.
struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @Bindable var tab: TabState

    var body: some View {
        List(selection: Binding(
            get: { tab.currentPath },
            set: { url in
                if let url { appState.navigate(to: url) }
            }
        )) {
            Section("Favorites") {
                ForEach(appState.fileService.sidebarLocations, id: \.url) { location in
                    Label(location.name, systemImage: location.icon)
                        .tag(location.url)
                }
            }

            Section("Volumes") {
                ForEach(appState.fileService.volumes, id: \.self) { volume in
                    Label(volume.lastPathComponent, systemImage: "externaldrive")
                        .tag(volume)
                }
            }

            Section("Folders") {
                FolderTreeNode(url: tab.currentPath.deletingLastPathComponent(), depth: 0)
            }
        }
        .listStyle(.sidebar)
    }
}

/// A recursive folder tree node that lazy-loads children on disclosure.
struct FolderTreeNode: View {
    @Environment(AppState.self) private var appState
    let url: URL
    let depth: Int

    @State private var children: [URL] = []
    @State private var isLoaded = false

    private static let maxDepth = 5

    var body: some View {
        if depth < Self.maxDepth {
            DisclosureGroup {
                ForEach(children, id: \.self) { childURL in
                    FolderTreeNode(url: childURL, depth: depth + 1)
                }
            } label: {
                Label(url.lastPathComponent, systemImage: "folder")
                    .tag(url)
                    .onTapGesture {
                        appState.navigate(to: url)
                    }
            }
            .onAppear {
                loadChildrenIfNeeded()
            }
        } else {
            Label(url.lastPathComponent, systemImage: "folder")
                .tag(url)
                .onTapGesture {
                    appState.navigate(to: url)
                }
        }
    }

    private func loadChildrenIfNeeded() {
        guard !isLoaded else { return }
        isLoaded = true
        children = appState.fileService.contentsOfDirectory(at: url)
            .filter(\.isDirectory)
            .map(\.url)
    }
}
