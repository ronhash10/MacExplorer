import Foundation
import AppKit

/// Provides file system operations: listing, metadata, and change watching.
final class FileSystemService {
    private let fileManager = FileManager.default

    /// List contents of a directory, returning FileItem models.
    func contentsOfDirectory(at url: URL, showHidden: Bool = false) -> [FileItem] {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [
                .isDirectoryKey, .fileSizeKey,
                .contentModificationDateKey, .localizedTypeDescriptionKey,
                .effectiveIconKey
            ],
            options: showHidden ? [] : [.skipsHiddenFiles]
        ) else {
            return []
        }

        return urls
            .map { FileItem(url: $0) }
            .sorted { lhs, rhs in
                // Folders first, then alphabetical
                if lhs.isDirectory != rhs.isDirectory {
                    return lhs.isDirectory
                }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    /// Check if a URL is a directory.
    func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return fileManager.isReadableFile(atPath: url.path) &&
               fileManager.fileExists(atPath: url.path, isDirectory: &isDir) &&
               isDir.boolValue
    }

    /// Move item to trash. Returns the URL of the item in the Trash (for undo).
    @discardableResult
    func moveToTrash(_ url: URL) throws -> URL? {
        var resultURL: NSURL?
        try fileManager.trashItem(at: url, resultingItemURL: &resultURL)
        return resultURL as URL?
    }

    /// Invisible metadata files that don't count as "real" content.
    private static let ignoredFiles: Set<String> = [".DS_Store", ".localized", "Thumbs.db"]

    /// Check if a directory contains any meaningful items (ignoring .DS_Store etc).
    func isDirectoryEmpty(_ url: URL) -> Bool {
        guard let contents = try? fileManager.contentsOfDirectory(atPath: url.path) else { return true }
        return contents.allSatisfy { Self.ignoredFiles.contains($0) }
    }

    /// Create a new folder at the given URL.
    func createFolder(at url: URL, name: String) throws -> URL {
        let folderURL = url.appendingPathComponent(name)
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: false)
        return folderURL
    }

    /// Standard sidebar locations.
    var sidebarLocations: [(name: String, url: URL, icon: String)] {
        let home = fileManager.homeDirectoryForCurrentUser
        return [
            ("Home", home, "house"),
            ("Desktop", home.appendingPathComponent("Desktop"), "menubar.dock.rectangle"),
            ("Documents", home.appendingPathComponent("Documents"), "doc"),
            ("Downloads", home.appendingPathComponent("Downloads"), "arrow.down.circle"),
            ("Applications", URL(fileURLWithPath: "/Applications"), "app.dashed"),
        ]
    }

    /// Mounted volumes.
    var volumes: [URL] {
        fileManager.mountedVolumeURLs(
            includingResourceValuesForKeys: [.volumeNameKey],
            options: [.skipHiddenVolumes]
        ) ?? []
    }

    /// Recursively search for files/folders matching a query in the given directory.
    /// Calls `onBatch` periodically with new matches and total files scanned so far.
    /// Checks `isCancelled` to support early termination.
    func searchFiles(
        in directory: URL,
        query: String,
        showHidden: Bool,
        isCancelled: @escaping () -> Bool,
        onProgress: @escaping (_ newItems: [FileItem], _ scanned: Int, _ isComplete: Bool) -> Void
    ) {
        let lowercasedQuery = query.lowercased()
        let resourceKeys: [URLResourceKey] = [
            .isDirectoryKey, .fileSizeKey,
            .contentModificationDateKey, .localizedTypeDescriptionKey,
            .effectiveIconKey, .isHiddenKey
        ]
        let maxResults = 10_000
        let batchSize = 200

        DispatchQueue.global(qos: .userInitiated).async {
            var batch: [FileItem] = []
            var totalMatches = 0
            var scanned = 0
            var lastFlushTime = CFAbsoluteTimeGetCurrent()

            guard let enumerator = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: resourceKeys,
                options: showHidden ? [.producesRelativePathURLs] : [.skipsHiddenFiles, .producesRelativePathURLs]
            ) else {
                DispatchQueue.main.async { onProgress([], 0, true) }
                return
            }

            while let url = enumerator.nextObject() as? URL {
                if isCancelled() || totalMatches >= maxResults { break }

                scanned += 1
                let name = url.lastPathComponent
                if Self.ignoredFiles.contains(name) { continue }

                if name.lowercased().contains(lowercasedQuery) {
                    let absoluteURL = directory.appendingPathComponent(url.relativePath)
                    batch.append(FileItem(url: absoluteURL))
                    totalMatches += 1
                }

                // Flush when we have a full batch or every 300ms for progress updates
                let now = CFAbsoluteTimeGetCurrent()
                if batch.count >= batchSize || (now - lastFlushTime >= 0.3) {
                    let items = batch
                    let count = scanned
                    batch = []
                    lastFlushTime = now
                    DispatchQueue.main.async { onProgress(items, count, false) }
                }
            }

            // Final flush with remaining items
            let finalItems = batch
            let finalCount = scanned
            DispatchQueue.main.async { onProgress(finalItems, finalCount, true) }
        }
    }
}
