import SwiftUI

/// Sheet showing potential duplicate files found in the current folder, letting the
/// user review each group and move the extras to Trash (undo-able via ⌘Z).
struct DuplicateFinderView: View {
    let tab: TabState
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var groups: [DuplicateGroup] = []
    @State private var filesToTrash: Set<FileItem.ID> = []
    @State private var hasScanned = false
    @State private var previewedFileID: FileItem.ID?
    @State private var previewWidth: CGFloat = 380
    @State private var fileHashes: [FileItem.ID: String] = [:]
    @FocusState private var listFocused: Bool

    private enum VerificationStatus {
        case pending, identical, different
    }

    private var previewedFile: FileItem? {
        groups.flatMap(\.files).first { $0.id == previewedFileID }
    }

    /// Compares a file's content hash against its group's kept (oldest) file.
    private func verificationStatus(for file: FileItem, in group: DuplicateGroup) -> VerificationStatus {
        guard let keepFile = group.files.first,
              let keepHash = fileHashes[keepFile.id],
              let fileHash = fileHashes[file.id] else { return .pending }
        return fileHash == keepHash ? .identical : .different
    }

    private var selectedCount: Int { filesToTrash.count }
    private var selectedSize: Int64 {
        groups.flatMap(\.files)
            .filter { filesToTrash.contains($0.id) }
            .reduce(0) { $0 + $1.size }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if !hasScanned {
                ProgressView("Scanning for duplicates…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if groups.isEmpty {
                emptyState
            } else {
                HStack(spacing: 0) {
                    resultsList
                        .frame(minWidth: 240, maxWidth: .infinity)
                    ResizableDivider(width: $previewWidth)
                    previewPane
                        .frame(width: previewWidth)
                        .frame(maxHeight: .infinity)
                }
                Divider()
                footer
            }
        }
        .frame(minWidth: 680, idealWidth: 860, maxWidth: .infinity,
               minHeight: 440, idealHeight: 560, maxHeight: .infinity)
        .background(ResizableSheetConfigurator(minSize: NSSize(width: 680, height: 440)))
        .task {
            groups = DuplicateFinder.findDuplicateGroups(in: tab.items)
            filesToTrash = Set(groups.flatMap { $0.files.dropFirst() }.map(\.id))
            previewedFileID = groups.first?.files.first?.id
            hasScanned = true
            listFocused = true

            // Verify byte-for-byte equality, since matching size + name prefix alone
            // can coincidentally group unrelated files.
            for file in groups.flatMap(\.files) {
                guard !Task.isCancelled else { return }
                let hash = await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
                    DispatchQueue.global(qos: .utility).async {
                        continuation.resume(returning: FileHasher.sha256(of: file.url))
                    }
                }
                guard !Task.isCancelled else { return }
                if let hash {
                    fileHashes[file.id] = hash
                }
            }
        }
    }

    @ViewBuilder
    private var previewPane: some View {
        if let file = previewedFile {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(nsImage: file.icon)
                        .resizable()
                        .frame(width: 20, height: 20)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(file.name)
                            .font(.callout.bold())
                            .lineLimit(1)
                        Text("\(file.formattedSize) · Created \(file.formattedCreatedDate)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(10)

                Divider()

                FileTypePreview(url: file.url)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 32))
                    .foregroundStyle(.quaternary)
                Text("Select a file to preview")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var header: some View {
        HStack {
            Text("Duplicate Files")
                .font(.headline)
            Spacer()
            if !groups.isEmpty {
                Button("Select All") {
                    filesToTrash = Set(groups.flatMap { $0.files.dropFirst() }.map(\.id))
                }
                .buttonStyle(.borderless)
                Button("Select None") {
                    filesToTrash.removeAll()
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(12)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No duplicates found")
                .font(.headline)
            Text("No files in this folder share both size and a matching name.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultsList: some View {
        List(selection: $previewedFileID) {
            ForEach(groups) { group in
                Section {
                    ForEach(group.files) { file in
                        fileRow(file, in: group)
                            .tag(file.id)
                    }
                } header: {
                    HStack {
                        Text("\(group.files.count) files · \(ByteCountFormatter.string(fromByteCount: group.files[0].size, countStyle: .file)) each")
                        Spacer()
                        Button(allSelected(in: group) ? "Deselect All" : "Select All") {
                            toggleAll(in: group)
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                }
            }
        }
        .focused($listFocused)
    }

    private func fileRow(_ file: FileItem, in group: DuplicateGroup) -> some View {
        let isOldest = file.id == group.files.first?.id
        return HStack(spacing: 10) {
            Toggle("", isOn: Binding(
                get: { filesToTrash.contains(file.id) },
                set: { isOn in
                    if isOn { filesToTrash.insert(file.id) } else { filesToTrash.remove(file.id) }
                }
            ))
            .labelsHidden()

            Image(nsImage: file.icon)
                .resizable()
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(file.name)
                        .lineLimit(1)
                    if isOldest {
                        Text("Keep")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(.green.opacity(0.2), in: Capsule())
                            .foregroundStyle(.green)
                    }
                }
                Text("Created \(file.formattedCreatedDate) · \(file.formattedSize)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !isOldest {
                verificationBadge(for: verificationStatus(for: file, in: group))
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func verificationBadge(for status: VerificationStatus) -> some View {
        switch status {
        case .pending:
            ProgressView()
                .controlSize(.mini)
        case .identical:
            Label("Identical", systemImage: "checkmark.seal.fill")
                .font(.caption2)
                .foregroundStyle(.green)
        case .different:
            Label("Different content", systemImage: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundStyle(.orange)
        }
    }

    private var footer: some View {
        HStack {
            Text(selectedCount > 0
                 ? "\(selectedCount) file\(selectedCount == 1 ? "" : "s") selected · \(ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file)) to free"
                 : "No files selected")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Cancel") { dismiss() }
            Button("Move \(selectedCount) to Trash", role: .destructive) {
                moveSelectedToTrash()
            }
            .disabled(selectedCount == 0)
        }
        .padding(12)
    }

    private func allSelected(in group: DuplicateGroup) -> Bool {
        group.files.dropFirst().allSatisfy { filesToTrash.contains($0.id) }
    }

    private func toggleAll(in group: DuplicateGroup) {
        let extras = group.files.dropFirst().map(\.id)
        if allSelected(in: group) {
            extras.forEach { filesToTrash.remove($0) }
        } else {
            extras.forEach { filesToTrash.insert($0) }
        }
    }

    private func moveSelectedToTrash() {
        let urls = groups.flatMap(\.files)
            .filter { filesToTrash.contains($0.id) }
            .map(\.url)
        appState.trashWithUndo(urls: urls)
        appState.refreshCurrentTab()
        dismiss()
    }
}

/// SwiftUI sheets on macOS don't become resizable just from flexible `.frame()`
/// bounds — the sheet's NSWindow needs `.resizable` added to its styleMask
/// directly. This invisible helper reaches into the hosting window to do that.
private struct ResizableSheetConfigurator: NSViewRepresentable {
    let minSize: NSSize

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.styleMask.insert(.resizable)
            window.minSize = minSize
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
