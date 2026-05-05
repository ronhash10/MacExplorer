import SwiftUI

/// Breadcrumb navigation bar with back/forward buttons and clickable path components.
struct BreadcrumbBar: View {
    @Environment(AppState.self) private var appState
    @Bindable var tab: TabState

    var body: some View {
        HStack(spacing: 6) {
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

            Spacer()

            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Filter", text: Binding(
                    get: { appState.searchQuery },
                    set: { appState.searchQuery = $0 }
                ))
                .textFieldStyle(.plain)
                .frame(width: 140)
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
