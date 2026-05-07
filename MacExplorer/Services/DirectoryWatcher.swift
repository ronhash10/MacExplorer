import Foundation
import CoreServices

/// Watches directories for filesystem changes using FSEvents.
/// Calls the onChange handler when files/folders are added, removed, or renamed.
final class DirectoryWatcher {
    private var stream: FSEventStreamRef?
    private let queue = DispatchQueue(label: "com.macexplorer.dirwatcher", qos: .utility)
    private var onChange: ((_ changedPaths: [String]) -> Void)?

    /// Start watching the given directories. Replaces any existing watch.
    func watch(paths: [String], onChange: @escaping (_ changedPaths: [String]) -> Void) {
        stop()
        guard !paths.isEmpty else { return }
        self.onChange = onChange

        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()

        let flags: FSEventStreamCreateFlags =
            UInt32(kFSEventStreamCreateFlagUseCFTypes)
            | UInt32(kFSEventStreamCreateFlagFileEvents)
            | UInt32(kFSEventStreamCreateFlagNoDefer)
            | UInt32(kFSEventStreamCreateFlagIgnoreSelf)

        guard let stream = FSEventStreamCreate(
            nil,
            DirectoryWatcher.callback,
            &context,
            paths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.3, // 300ms coalescing — fast but filters save storms
            flags
        ) else { return }

        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
        self.onChange = nil
    }

    deinit {
        stop()
    }

    // MARK: - FSEvents C Callback

    private static let callback: FSEventStreamCallback = {
        _, info, numEvents, eventPaths, eventFlags, _ in

        guard let info, let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] else { return }
        let watcher = Unmanaged<DirectoryWatcher>.fromOpaque(info).takeUnretainedValue()

        // Filter to meaningful events (created, removed, renamed, modified)
        let meaningfulMask: FSEventStreamEventFlags =
            UInt32(kFSEventStreamEventFlagItemCreated)
            | UInt32(kFSEventStreamEventFlagItemRemoved)
            | UInt32(kFSEventStreamEventFlagItemRenamed)
            | UInt32(kFSEventStreamEventFlagItemModified)
            | UInt32(kFSEventStreamEventFlagMustScanSubDirs)
            | UInt32(kFSEventStreamEventFlagRootChanged)

        var changedPaths: Set<String> = []
        for i in 0..<numEvents {
            let flags = eventFlags[i]
            if flags & meaningfulMask != 0 {
                // Report the parent directory of the changed item
                let path = paths[i]
                let parentPath = (path as NSString).deletingLastPathComponent
                changedPaths.insert(parentPath)
            }
        }

        guard !changedPaths.isEmpty else { return }
        let changed = Array(changedPaths)
        DispatchQueue.main.async {
            watcher.onChange?(changed)
        }
    }
}
