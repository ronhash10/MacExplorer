import Foundation
import CryptoKit

/// A group of files considered potential duplicates (same size, matching name prefix).
/// `files` is sorted oldest-first by creation date.
struct DuplicateGroup: Identifiable {
    let id = UUID()
    let files: [FileItem]
}

/// Finds potential duplicate files within a single folder's listing.
enum DuplicateFinder {
    /// Groups files that share identical size and a matching filename prefix (stem,
    /// case-insensitive). Matches are transitive: if A matches B and B matches C,
    /// all three land in one group. Only files (not folders) are considered, and
    /// zero-byte files are excluded to avoid trivial matches.
    static func findDuplicateGroups(in items: [FileItem]) -> [DuplicateGroup] {
        let candidates = items.filter { !$0.isDirectory && $0.size > 0 }
        let bySize = Dictionary(grouping: candidates, by: \.size)

        var groups: [DuplicateGroup] = []
        for (_, files) in bySize where files.count > 1 {
            groups.append(contentsOf: connectedComponents(of: files))
        }

        // Dictionary iteration order is unspecified, so without this the group
        // order would vary from run to run.
        return groups.sorted {
            $0.files[0].name.localizedStandardCompare($1.files[0].name) == .orderedAscending
        }
    }

    /// Partitions files within one size bucket into groups via prefix-matching stems.
    private static func connectedComponents(of files: [FileItem]) -> [DuplicateGroup] {
        let stems = files.map { $0.url.deletingPathExtension().lastPathComponent.lowercased() }

        var parent = Array(0..<files.count)
        func find(_ i: Int) -> Int {
            var i = i
            while parent[i] != i { i = parent[i] }
            return i
        }
        func union(_ a: Int, _ b: Int) {
            let rootA = find(a), rootB = find(b)
            if rootA != rootB { parent[rootB] = rootA }
        }

        for i in 0..<files.count {
            for j in (i + 1)..<files.count {
                if isPrefixMatch(stems[i], stems[j]) {
                    union(i, j)
                }
            }
        }

        var componentsByRoot: [Int: [FileItem]] = [:]
        for i in 0..<files.count {
            componentsByRoot[find(i), default: []].append(files[i])
        }

        return componentsByRoot.values
            .filter { $0.count > 1 }
            .map { DuplicateGroup(files: $0.sorted { $0.dateCreated < $1.dateCreated }) }
    }

    private static func isPrefixMatch(_ a: String, _ b: String) -> Bool {
        a.hasPrefix(b) || b.hasPrefix(a)
    }
}

/// Verifies whether same-size, similarly-named files are true byte-for-byte
/// duplicates, since matching size and name prefix alone can coincidentally
/// group unrelated files.
enum FileHasher {
    /// SHA-256 hex digest of a file's contents, read in chunks so large files
    /// don't need to be loaded into memory all at once. Returns nil if the
    /// file can't be read.
    static func sha256(of url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        var hasher = SHA256()
        while let chunk = try? handle.read(upToCount: 1_048_576), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
