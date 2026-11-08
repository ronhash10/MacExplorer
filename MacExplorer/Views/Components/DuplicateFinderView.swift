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
                resultsList
                Divider()
                footer
            }
        }
        .frame(width: 560, height: 480)
        .task {
            groups = DuplicateFinder.findDuplicateGroups(in: tab.items)
            filesToTrash = Set(groups.flatMap { $0.files.dropFirst() }.map(\.id))
            hasScanned = true
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
        List {
            ForEach(groups) { group in
                Section {
                    ForEach(group.files) { file in
                        fileRow(file, in: group)
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
        }
        .padding(.vertical, 2)
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
