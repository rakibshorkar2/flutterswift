import Foundation
import OSLog

private let logger = Logger(subsystem: "com.dirxplorerakib.pro", category: "DirectoryMonitor")

/// Monitors the app's Documents directory for changes made via the Files app.
/// Uses GCD dispatch source to watch for file system events.
public actor DirectoryMonitor {

    public static let shared = DirectoryMonitor()

    /// Called when a change is detected. Passes the list of affected file paths.
    public var onChange: (([String]) -> Void)?

    private var source: DispatchSourceFileSystemObject?
    private var monitoredURL: URL?
    private var isMonitoring = false

    private init() {}

    /// Start monitoring the Downloads directory.
    public func startMonitoring() {
        let dir = StorageManager.shared.downloadsDirectory
        guard !isMonitoring else { return }

        let fd = open(dir.path, O_EVTONLY)
        guard fd >= 0 else {
            logger.error("Cannot open directory for monitoring: \(dir.path)")
            return
        }

        let newSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .extend],
            queue: DispatchQueue.global(qos: .utility)
        )

        newSource.setEventHandler { [weak self] in
            Task {
                await self?.handleChange()
            }
        }

        newSource.setCancelHandler {
            close(fd)
        }

        self.source = newSource
        self.monitoredURL = dir
        self.isMonitoring = true
        newSource.resume()
        logger.info("Started monitoring: \(dir.path)")
    }

    /// Stop monitoring.
    public func stopMonitoring() {
        source?.cancel()
        source = nil
        isMonitoring = false
        monitoredURL = nil
    }

    // MARK: - Manual Refresh

    /// Force a scan and emit change event.
    public func refresh() {
        handleChange()
    }

    // MARK: - Private

    private func handleChange() {
        // Debounce: collect changes briefly
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            // Re-scan the directory and notify
            let files = StorageManager.shared.listFiles(in: StorageManager.shared.downloadsDirectory)
            let paths = files.map(\.path)
            onChange?(paths)
        }
    }
}
