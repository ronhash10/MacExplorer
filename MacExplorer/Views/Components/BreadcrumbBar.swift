import SwiftUI

/// Breadcrumb navigation bar with back/forward buttons and clickable path components.
struct BreadcrumbBar: View {
    @Environment(AppState.self) private var appState
    @Bindable var tab: TabState
    @State private var searchText: String = ""

    var body: some View {
        HStack(spacing: 6) {
            if !tab.isSearchTab {
                // Back / Forward buttons
                Button(action: {
                    tab.goBack()
                    appState.refreshCurrentTab()
                }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 12, weight: .medium))
                }
                .disabled(!tab.canGoBack)
                .buttonStyle(.borderless)

                Button(action: {
                    tab.goForward()
                    appState.refreshCurrentTab()
                }) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .medium))
                }
                .disabled(!tab.canGoForward)
                .buttonStyle(.borderless)

                Divider()
                    .frame(height: 16)

                // Breadcrumb path
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(Array(tab.pathComponents.enumerated()), id: \.offset) { index, component in
                            if index > 0 {
                                Image(systemName: "arrowtriangle.right.fill")
                                    .font(.system(size: 6))
                                    .foregroundStyle(.tertiary)
                            }

                            Button(component.name) {
                                appState.navigate(to: component.url)
                            }
                            .buttonStyle(.borderless)
                            .font(.callout)
                            .foregroundStyle(
                                component.url == tab.currentPath ? .primary : .secondary
                            )
                        }
                    }
                }
                .focusable(false)
            } else {
                // Search tab: show search info
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                Text("Results for \"\(tab.searchQuery ?? "")\" in \(tab.searchRootPath?.lastPathComponent ?? "")")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Search field
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .frame(width: 140)
                    .onSubmit {
                        let path = tab.isSearchTab ? (tab.searchRootPath ?? tab.currentPath) : tab.currentPath
                        appState.performSearch(query: searchText, from: path)
                        searchText = ""
                    }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }
}
