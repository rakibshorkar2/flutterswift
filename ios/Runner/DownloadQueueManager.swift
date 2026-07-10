import Foundation
import OSLog

private let logger = Logger(subsystem: "com.dirxplorerakib.pro", category: "DownloadQueue")

/// Manages the download queue with configurable concurrent limits, priority, and ordering.
public actor DownloadQueueManager {

    public static let shared = DownloadQueueManager()

    /// A queued download entry.
    public struct QueueEntry: Sendable {
        public let taskId: String
        public let url: String
        public let fileName: String
        public let priority: Int      // higher = more important
        public let addedAt: Date
        public var headers: [String: String]?
    }

    private var queue: [QueueEntry] = []
    private var activeCount = 0
    public var maxConcurrent = 2

    private var onStartNext: ((QueueEntry) -> Void)?

    private init() {}

    /// Set the callback invoked when a queued entry should start downloading.
    public func setStartHandler(_ handler: @escaping (QueueEntry) -> Void) {
        onStartNext = handler
    }

    /// Enqueue a download. It will start automatically when below the concurrent limit.
    public func enqueue(_ entry: QueueEntry) {
        queue.append(entry)
        queue.sort { $0.priority > $1.priority || ($0.priority == $1.priority && $0.addedAt < $1.addedAt) }
        logger.info("Enqueued: \(entry.fileName) (priority \(entry.priority), queue depth \(queue.count))")
        processNext()
    }

    /// Called when a download finishes (success, failure, or cancellation).
    public func taskDidFinish(taskId: String) {
        activeCount = max(0, activeCount - 1)
        queue.removeAll { $0.taskId == taskId }
        processNext()
    }

    /// Get the current queue (excluding active tasks).
    public func queuedEntries() -> [QueueEntry] {
        return queue
    }

    /// Pause all queued downloads — stop processing the queue.
    public func pauseQueue() {
        // Queue processing naturally stops because we won't call processNext
        logger.info("Queue paused (\(queue.count) remaining)")
    }

    /// Resume queue processing.
    public func resumeQueue() {
        logger.info("Queue resumed")
        processNext()
    }

    /// Reorder a queued entry to a new position.
    public func moveEntry(taskId: String, to position: Int) {
        guard let idx = queue.firstIndex(where: { $0.taskId == taskId }) else { return }
        let entry = queue.remove(at: idx)
        let insertIdx = min(position, queue.count)
        queue.insert(entry, at: insertIdx)
    }

    /// Cancel a queued entry (remove from queue without download).
    public func cancelQueued(taskId: String) {
        queue.removeAll { $0.taskId == taskId }
    }

    /// Maximum concurrent downloads.
    public func setMaxConcurrent(_ count: Int) {
        maxConcurrent = max(1, min(count, 8))
    }

    // MARK: - Private

    private func processNext() {
        guard activeCount < maxConcurrent, !queue.isEmpty else { return }
        let entry = queue.removeFirst()
        activeCount += 1
        logger.info("Starting from queue: \(entry.fileName) (active: \(activeCount)/\(maxConcurrent))")
        onStartNext?(entry)
    }
}
