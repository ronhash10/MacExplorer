import SwiftUI
import QuickLookUI

/// Preview pane showing file information and a QuickLook preview for selected files.
struct PreviewPane: View {
    @Environment(AppState.self) private var appState
    let tab: TabState

    private var selectedItem: FileItem? {
        guard let id = tab.selectedItems.first else { return nil }
        return tab.items.first { $0.id == id }
    }

    var body: some View {
        Group {
            if let item = selectedItem {
                VStack(spacing: 0) {
                    // QuickLook preview
                    if !item.isDirectory {
                        QuickLookPreview(url: item.url)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    Divider()

                    // File info
                    fileInfoView(for: item)
                        .padding(12)
                }
            } else {
                VStack {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 40))
                        .foregroundStyle(.quaternary)
                    Text("Select a file to preview")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(.background)
    }

    @ViewBuilder
    private func fileInfoView(for item: FileItem) -> some View {
        HStack(spacing: 16) {
            Image(nsImage: item.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .lineLimit(1)

                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 2) {
                    GridRow {
                        Text("Kind:").foregroundStyle(.secondary)
                        Text(item.kind)
                    }
                    if !item.isDirectory {
                        GridRow {
                            Text("Size:").foregroundStyle(.secondary)
                            Text(item.formattedSize)
                        }
                    }
                    GridRow {
                        Text("Modified:").foregroundStyle(.secondary)
                        Text(item.formattedDate)
                    }
                    GridRow {
                        Text("Path:").foregroundStyle(.secondary)
                        Text(item.url.path)
                            .lineLimit(1)
                            .truncationMode(.head)
                    }
                }
                .font(.callout)
            }

            Spacer()
        }
    }
}

/// NSViewRepresentable wrapping QLPreviewView for inline file previews.
struct QuickLookPreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .compact)!
        view.previewItem = url as QLPreviewItem
        return view
    }

    func updateNSView(_ nsView: QLPreviewView, context: Context) {
        nsView.previewItem = url as QLPreviewItem
    }
}
