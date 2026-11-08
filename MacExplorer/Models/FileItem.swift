import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Represents a single file or directory entry.
@Observable
final class FileItem: Identifiable, Hashable, Transferable {
    let id: String
    let name: String
    let url: URL
    let isDirectory: Bool
    /// True for bundles like `.app` — directories on disk that are treated as a
    /// single file. Their `fileSizeKey` resource value is meaningless (it's a
    /// directory underneath), so they need the same recursive size as folders.
    let isPackage: Bool
    let size: Int64
    let dateModified: Date
    let dateCreated: Date
    let kind: String
    let icon: NSImage
    let isEmptyFolder: Bool

    /// Recursive content size for directories, filled in lazily by the file list
    /// (directories report 0 for their own `fileSize` resource value, which isn't
    /// useful). `nil` until computed.
    var folderSize: Int64?
    var isComputingFolderSize = false

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation { item in
            item.url as URL
        }
    }

    init(url: URL) {
        self.url = url
        self.id = url.absoluteString
        self.name = url.lastPathComponent

        let resourceValues = try? url.resourceValues(forKeys: [
            .isDirectoryKey, .isPackageKey, .fileSizeKey, .contentModificationDateKey,
            .creationDateKey, .localizedTypeDescriptionKey, .effectiveIconKey
        ])

        let isDir = resourceValues?.isDirectory ?? false
        let isPackage = resourceValues?.isPackage ?? false
        // .app bundles and other packages are directories but should be treated as files
        self.isDirectory = isDir && !isPackage
        self.isPackage = isDir && isPackage
        self.size = Int64(resourceValues?.fileSize ?? 0)
        self.dateModified = resourceValues?.contentModificationDate ?? Date.distantPast
        self.dateCreated = resourceValues?.creationDate ?? Date.distantPast
        self.kind = resourceValues?.localizedTypeDescription ?? (self.isDirectory ? "Folder" : "Document")
        self.icon = (resourceValues?.effectiveIcon as? NSImage) ?? NSWorkspace.shared.icon(for: .data)

        if self.isDirectory {
            // Lightweight check: see if folder has at least one visible non-metadata item
            let contents = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
            let ignoredFiles: Set<String> = [".DS_Store", ".localized", "Thumbs.db"]
            self.isEmptyFolder = contents.allSatisfy { $0.hasPrefix(".") || ignoredFiles.contains($0) }
        } else {
            self.isEmptyFolder = false
        }
    }

    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// True for anything whose size comes from `folderSize` (a recursive scan)
    /// rather than the raw `size` resource value: directories, and packages like
    /// `.app` bundles that are directories underneath despite acting like files.
    var usesFolderSize: Bool { isDirectory || isPackage }

    /// Value the Size column sorts on: a directory's (or package's) computed
    /// content size once known (0 until then), or a file's actual size. `size`
    /// itself stays the raw filesystem entry size, which is near-zero and
    /// meaningless for directories.
    var sizeForSorting: Int64 {
        usesFolderSize ? (folderSize ?? 0) : size
    }

    var formattedSize: String {
        if usesFolderSize {
            guard let folderSize else { return "—" }
            return ByteCountFormatter.string(fromByteCount: folderSize, countStyle: .file)
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var formattedDate: String {
        Self.dateFormatter.string(from: dateModified)
    }

    var formattedCreatedDate: String {
        Self.dateFormatter.string(from: dateCreated)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}
