import AppKit

/// Moves items to trash with confirmation for non-empty folders.
enum TrashHelper {
    /// Move URLs to trash. Shows a confirmation alert if any folder is non-empty.
    /// Returns true if the operation proceeded, false if cancelled.
    @discardableResult
    static func moveToTrash(_ urls: [URL], using service: FileSystemService, refreshAction: @escaping () -> Void) -> Bool {
        let nonEmptyFolders = urls.filter { url in
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            let isPackage = (try? url.resourceValues(forKeys: [.isPackageKey]))?.isPackage ?? false
            return isDir && !isPackage && !service.isDirectoryEmpty(url)
        }

        if !nonEmptyFolders.isEmpty {
            let alert = NSAlert()
            alert.messageText = "Move to Trash?"
            if nonEmptyFolders.count == 1 {
                let name = nonEmptyFolders[0].lastPathComponent
                alert.informativeText = "\"\(name)\" is not empty. Are you sure you want to move it to the Trash?"
            } else {
                alert.informativeText = "\(nonEmptyFolders.count) folders are not empty. Are you sure you want to move them to the Trash?"
            }
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Move to Trash")
            alert.addButton(withTitle: "Cancel")
            let response = alert.runModal()
            guard response == .alertFirstButtonReturn else { return false }
        }

        for url in urls {
            try? service.moveToTrash(url)
        }
        refreshAction()
        return true
    }
}
