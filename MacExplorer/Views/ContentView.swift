import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            TabBarView()
            Divider()
            mainContent
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if let tab = appState.currentTab {
            HSplitView {
                SidebarView(tab: tab)
                    .frame(minWidth: 180, idealWidth: 220, maxWidth: 350)

                VStack(spacing: 0) {
                    BreadcrumbBar(tab: tab)
                    Divider()

                    if appState.showPreview {
                        VSplitView {
                            FileListView(tab: tab)
                            PreviewPane(tab: tab)
                                .frame(minHeight: 120, idealHeight: 200)
                        }
                    } else {
                        FileListView(tab: tab)
                    }

                    Divider()
                    StatusBar(tab: tab)
                }
            }
        } else {
            Text("No tabs open. Press ⌘T to create a new tab.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
