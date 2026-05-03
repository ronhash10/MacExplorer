import SwiftUI
import QuickLookUI

/// Preview pane showing file information and a QuickLook preview for selected files.
struct PreviewPane: View {
    @Environment(AppState.self) private var appState
    let tab: TabState

    private var selectedItems: [FileItem] {
        tab.items.filter { tab.selectedItems.contains($0.id) }
    }

    private var isSingleSelection: Bool {
        selectedItems.count == 1
    }

    var body: some View {
        Group {
            if selectedItems.count > 1 {
                // Multi-selection: show summary, no preview
                multiSelectionView
            } else if let item = selectedItems.first {
                VStack(spacing: 0) {
                    fileInfoView(for: item)
                        .padding(12)

                    Divider()

                    if !item.isDirectory {
                        QuickLookPreview(url: item.url)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        Spacer()
                    }
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

    @ViewBuilder
    private var multiSelectionView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("\(selectedItems.count) items selected")
                .font(.headline)

            let totalSize = selectedItems
                .filter { !$0.isDirectory }
                .reduce(Int64(0)) { $0 + $1.size }
            let fileCount = selectedItems.filter { !$0.isDirectory }.count
            let folderCount = selectedItems.filter { $0.isDirectory }.count

            VStack(spacing: 4) {
                if fileCount > 0 {
                    Text("\(fileCount) file\(fileCount == 1 ? "" : "s")")
                        .foregroundStyle(.secondary)
                }
                if folderCount > 0 {
                    Text("\(folderCount) folder\(folderCount == 1 ? "" : "s")")
                        .foregroundStyle(.secondary)
                }
                Text("Total size: \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))")
                    .foregroundStyle(.secondary)
            }
            .font(.callout)

            Spacer()
        }
        .padding(.top, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
