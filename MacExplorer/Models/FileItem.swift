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
    let size: Int64
    let dateModified: Date
    let kind: String
    let icon: NSImage
    let isEmptyFolder: Bool

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
            .localizedTypeDescriptionKey, .effectiveIconKey
        ])

        let isDir = resourceValues?.isDirectory ?? false
        let isPackage = resourceValues?.isPackage ?? false
        // .app bundles and other packages are directories but should be treated as files
        self.isDirectory = isDir && !isPackage
        self.size = Int64(resourceValues?.fileSize ?? 0)
        self.dateModified = resourceValues?.contentModificationDate ?? Date.distantPast
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

    var formattedSize: String {
        guard !isDirectory else { return "—" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var formattedDate: String {
        Self.dateFormatter.string(from: dateModified)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}
