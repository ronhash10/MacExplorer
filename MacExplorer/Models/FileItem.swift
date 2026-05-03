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

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .fileURL) { item in
            SentTransferredFile(item.url)
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
