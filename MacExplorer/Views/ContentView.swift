import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var previewWidth: CGFloat = {
        let saved = UserDefaults.standard.double(forKey: "previewPaneWidth")
        return saved > 0 ? saved : 350
    }()

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

                    HStack(spacing: 0) {
                        FileListView(tab: tab)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        if appState.showPreview {
                            ResizableDivider(width: $previewWidth)
                            PreviewPane(tab: tab)
                                .frame(width: previewWidth)
                                .frame(maxHeight: .infinity)
                        }
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

/// Draggable divider for resizing the preview pane.
struct ResizableDivider: View {
    @Binding var width: CGFloat
    @State private var startWidth: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(width: 5)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if startWidth == 0 { startWidth = width }
                        let newWidth = max(200, min(900, startWidth - value.translation.width))
                        width = newWidth
                    }
                    .onEnded { _ in
                        startWidth = 0
                        UserDefaults.standard.set(width, forKey: "previewPaneWidth")
                    }
            )
    }
}
