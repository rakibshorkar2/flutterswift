import Foundation
import OSLog

private let logger = Logger(subsystem: "com.dirxplorerakib.pro", category: "BackgroundDownloader")

/// Extended download statuses for the professional engine.
@objc public enum DXDownloadStatus: Int {
    case idle, connecting, fetchingHeaders, downloading, paused, queued,
         completed, failed, retrying, expired, waiting, verifying, merging, cancelled
}

/// Thread-safe model for a download task.
@objc public class DXDownloadTask: NSObject {
    @objc public let taskId: String
    @objc public let url: String
    @objc public var fileName: String
    @objc public let destinationPath: String
    @objc public var status: DXDownloadStatus = .idle
    @objc public var progress: Double = 0.0
    @objc public var speedBytesPerSec: Double = 0.0
    @objc public var etaSeconds: Int = 0
    @objc public var totalBytes: Int64 = 0
    @objc public var receivedBytes: Int64 = 0
    @objc public var resumeData: Data?
    @objc public var errorMessage: String?
    @objc public let createdAt: Date
    @objc public var completedAt: Date?
    @objc public var mimeType: String = ""
    @objc public var fileExtension: String = ""
    @objc public var server: String = ""
    @objc public var etag: String = ""
    @objc public var supportsResume: Bool = false
    @objc public var retryCount: Int = 0
    @objc public var category: String = "other"
    @objc public var sourceDomain: String = ""
    @objc public var headers: [String: String]?

    private var speedSamples: [(date: Date, bytes: Int64)] = []

    public init(taskId: String, url: String, fileName: String, destinationPath: String) {
        self.taskId = taskId
        self.url = url
        self.fileName = fileName
        self.destinationPath = destinationPath
        self.createdAt = Date()
        if let host = URL(string: url)?.host {
            self.sourceDomain = host
        }
        let ext = (fileName as NSString).pathExtension.lowercased()
        self.fileExtension = ext
        self.category = Self.category(for: ext)
    }

    /// Classify file extension into a category.
    private static func category(for ext: String) -> String {
        switch ext {
        case "mkv", "mp4", "avi", "mov", "wmv", "flv", "webm", "m4v", "ts", "m2ts":
            return "video"
        case "mp3", "flac", "wav", "aac", "ogg", "wma", "m4a", "opus":
            return "audio"
        case "zip", "rar", "7z", "tar", "gz", "bz2", "xz", "zst":
            return "archive"
        case "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "csv", "rtf":
            return "document"
        case "jpg", "jpeg", "png", "gif", "bmp", "webp", "svg", "heic", "avif":
            return "image"
        case "ipa", "apk", "dmg", "exe", "msi", "deb", "rpm":
            return "app"
        case "iso", "img":
            return "disk"
        default:
            return "other"
        }
    }

    public func recordProgress(receivedBytes: Int64, totalBytes: Int64) {
        self.receivedBytes = receivedBytes
        self.totalBytes = totalBytes
        self.progress = totalBytes > 0 ? Double(receivedBytes) / Double(totalBytes) : 0

        let now = Date()
        speedSamples.append((date: now, bytes: receivedBytes))
        speedSamples = speedSamples.filter { now.timeIntervalSince($0.date) <= 3.0 }

        if speedSamples.count >= 2,
           let oldest = speedSamples.first {
            let elapsed = now.timeIntervalSince(oldest.date)
            let bytesInWindow = receivedBytes - oldest.bytes
            speedBytesPerSec = elapsed > 0 ? Double(bytesInWindow) / elapsed : 0
        }

        if speedBytesPerSec > 0, totalBytes > 0 {
            let remaining = totalBytes - receivedBytes
            etaSeconds = Int(Double(remaining) / speedBytesPerSec)
        } else {
            etaSeconds = 0
        }
    }

    public func statusString() -> String {
        switch status {
        case .idle: return "idle"
        case .connecting: return "connecting"
        case .fetchingHeaders: return "fetchingHeaders"
        case .downloading: return "downloading"
        case .paused: return "paused"
        case .queued: return "queued"
        case .completed: return "completed"
        case .failed: return "failed"
        case .retrying: return "retrying"
        case .expired: return "expired"
        case .waiting: return "waiting"
        case .verifying: return "verifying"
        case .merging: return "merging"
        case .cancelled: return "cancelled"
        @unknown default: return "unknown"
        }
    }

    public func toDict() -> [String: Any] {
        var dict: [String: Any] = [
            "taskId": taskId,
            "url": url,
            "fileName": fileName,
            "destinationPath": destinationPath,
            "status": statusString(),
            "progress": progress,
            "speed": speedBytesPerSec,
            "eta": etaSeconds,
            "totalBytes": totalBytes,
            "receivedBytes": receivedBytes,
            "createdAt": ISO8601DateFormatter().string(from: createdAt),
            "mimeType": mimeType,
            "fileExtension": fileExtension,
            "server": server,
            "etag": etag,
            "supportsResume": supportsResume,
            "retryCount": retryCount,
            "category": category,
            "sourceDomain": sourceDomain,
            "errorMessage": errorMessage ?? "",
        ]
        if let completed = completedAt {
            dict["completedAt"] = ISO8601DateFormatter().string(from: completed)
        }
        return dict
    }
}

// MARK: - Professional Background Download Engine

public actor BackgroundDownloader: NSObject {
    public static let shared = BackgroundDownloader()

    private static let sessionId = "com.dirxplorerakib.pro.bgdownload"
    private let maxRetries = 3

    private var urlSession: URLSession!
    private var tasks: [String: DXDownloadTask] = [:]
    private var sessionTaskToTaskId: [Int: String] = [:]
    private var retryTimers: [String: Task<Void, Never>] = [:]

    public var onProgressUpdate: (([String: Any]) -> Void)?

    private override init() {}

    public func configure() {
        let config = URLSessionConfiguration.background(withIdentifier: Self.sessionId)
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.allowsCellularAccess = true
        config.waitsForConnectivity = true
        config.shouldUseExtendedBackgroundIdleMode = true
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)

        // Restore persisted downloads
        Task { await restoreTasks() }
    }

    /// Restore previously persisted tasks on app launch.
    private func restoreTasks() {
        let persisted = DownloadPersistence.shared.loadAll()
        for record in persisted {
            guard record.status != "completed" && record.status != "cancelled" else { continue }
            let destPath = record.destinationPath
            let task = DXDownloadTask(
                taskId: record.taskId,
                url: record.url,
                fileName: record.fileName,
                destinationPath: destPath
            )
            task.totalBytes = record.totalBytes
            task.receivedBytes = record.receivedBytes
            task.etag = record.etag
            task.status = .paused
            task.retryCount = record.retryCount
            task.category = record.category
            task.headers = record.headers
            task.resumeData = record.resumeData
            tasks[record.taskId] = task
            broadcastUpdate(task: task)
            logger.info("Restored task: \(record.fileName) (\(record.status))")
        }
    }

    public func configureProgressCallback(_ callback: @escaping ([String: Any]) -> Void) {
        onProgressUpdate = callback
    }

    // MARK: - Analyze URL before download

    /// Perform HEAD request to analyze a URL. Returns metadata map.
    public func analyzeURL(urlString: String, headers: [String: String]? = nil) async -> [String: Any] {
        guard let url = URL(string: urlString) else { return [:] }
        let meta = await URLMetadataAnalyzer.shared.analyze(url: url, headers: headers)
        return [
            "fileName": meta.fileName,
            "mimeType": meta.mimeType,
            "fileExtension": meta.fileExtension,
            "fileSize": meta.fileSize,
            "supportsResume": meta.supportsResume,
            "supportsRange": meta.supportsRange,
            "contentDisposition": meta.contentDisposition,
            "server": meta.server,
            "etag": meta.etag,
            "lastModified": meta.lastModified,
            "finalURL": meta.finalURL,
            "statusCode": meta.statusCode,
            "acceptRanges": meta.acceptRanges,
        ]
    }

    // MARK: - Start / Queue / Pause / Resume / Cancel

    /// Start a download. If the concurrent limit is reached, it's queued.
    @discardableResult
    public func startDownload(url urlString: String,
                              fileName: String,
                              destinationPath: String? = nil,
                              headers: [String: String]? = nil) -> String {
        guard let url = URL(string: urlString) else { return "" }

        let taskId = UUID().uuidString
        let destPath = destinationPath ?? Self.defaultDestination(for: fileName)

        let task = DXDownloadTask(
            taskId: taskId,
            url: urlString,
            fileName: fileName,
            destinationPath: destPath
        )
        task.headers = headers
        tasks[taskId] = task

        // Persist immediately
        persistTask(task)

        // Check if we can start immediately or need to queue
        let activeCount = tasks.values.filter { $0.status == .downloading || $0.status == .connecting }.count
        let maxConcurrent = DownloadQueueManager.shared.maxConcurrent

        if activeCount < maxConcurrent {
            beginDownload(task: task, url: url)
        } else {
            task.status = .queued
            broadcastUpdate(task: task)
            persistTask(task)
            logger.info("Queued: \(fileName) (active: \(activeCount)/\(maxConcurrent))")
        }

        return taskId
    }

    private func beginDownload(task: DXDownloadTask, url: URL) {
        task.status = .connecting
        broadcastUpdate(task: task)

        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        task.headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let sessionTask = urlSession.downloadTask(with: request)
        sessionTaskToTaskId[sessionTask.taskIdentifier] = task.taskId
        task.status = .downloading
        sessionTask.resume()
        persistTask(task)
        logger.info("Started download: \(task.fileName)")
    }

    public func pauseDownload(taskId: String) {
        guard let dxTask = tasks[taskId] else { return }

        // If queued, just mark as paused
        if dxTask.status == .queued {
            dxTask.status = .paused
            broadcastUpdate(task: dxTask)
            persistTask(dxTask)
            return
        }

        guard let sessionTaskId = sessionTaskToTaskId.first(where: { $0.value == taskId })?.key else { return }

        urlSession.getAllTasks { [weak self] sessionTasks in
            Task {
                await self?.doPause(sessionTasks: sessionTasks, sessionTaskId: sessionTaskId, dxTask: dxTask)
            }
        }
    }

    private func doPause(sessionTasks: [URLSessionTask], sessionTaskId: Int, dxTask: DXDownloadTask) {
        guard let dlTask = sessionTasks.first(where: { $0.taskIdentifier == sessionTaskId }) as? URLSessionDownloadTask else { return }
        dlTask.cancel { [weak self] resumeData in
            Task {
                await self?.saveResumeData(resumeData, for: dxTask.taskId)
            }
        }
        dxTask.status = .paused
        retryTimers[dxTask.taskId]?.cancel()
        broadcastUpdate(task: dxTask)
        persistTask(dxTask)
    }

    private func saveResumeData(_ data: Data?, for taskId: String) {
        tasks[taskId]?.resumeData = data
        if let task = tasks[taskId] {
            persistTask(task)
        }
    }

    public func resumeDownload(taskId: String) {
        guard let dxTask = tasks[taskId] else { return }

        // If completed or already downloading, skip
        if dxTask.status == .completed || dxTask.status == .downloading { return }

        // Download from where we left off using resume data or range request
        if let resumeData = dxTask.resumeData, dxTask.receivedBytes > 0 {
            let sessionTask = urlSession.downloadTask(withResumeData: resumeData)
            sessionTaskToTaskId[sessionTask.taskIdentifier] = taskId
            dxTask.status = .downloading
            dxTask.resumeData = nil
            sessionTask.resume()
        } else {
            guard let url = URL(string: dxTask.url) else { return }

            // Use Range header for resume when resume data not available
            var request = URLRequest(url: url)
            dxTask.headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }

            if dxTask.receivedBytes > 0 && dxTask.supportsResume {
                let range = "bytes=\(dxTask.receivedBytes)-"
                request.setValue(range, forHTTPHeaderField: "Range")
            }

            let sessionTask = urlSession.downloadTask(with: request)
            sessionTaskToTaskId[sessionTask.taskIdentifier] = taskId
            dxTask.status = .downloading
            sessionTask.resume()
        }
        broadcastUpdate(task: dxTask)
        persistTask(dxTask)
    }

    public func cancelDownload(taskId: String) {
        guard let dxTask = tasks[taskId] else { return }

        // Cancel retry timer
        retryTimers[taskId]?.cancel()

        guard let sessionTaskId = sessionTaskToTaskId.first(where: { $0.value == taskId })?.key else {
            dxTask.status = .cancelled
            broadcastUpdate(task: dxTask)
            tasks.removeValue(forKey: taskId)
            DownloadPersistence.shared.remove(taskId: taskId)
            DownloadQueueManager.shared.taskDidFinish(taskId: taskId)
            return
        }

        urlSession.getAllTasks { sessionTasks in
            sessionTasks.first(where: { $0.taskIdentifier == sessionTaskId })?.cancel()
        }
        dxTask.status = .cancelled
        broadcastUpdate(task: dxTask)
        tasks.removeValue(forKey: taskId)
        DownloadPersistence.shared.remove(taskId: taskId)
        sessionTaskToTaskId.removeValue(forKey: sessionTaskId)
        DownloadQueueManager.shared.taskDidFinish(taskId: taskId)
    }

    /// Refresh an expired/expiring download with a new URL.
    public func refreshDownload(taskId: String, newURL: String) -> Bool {
        guard let dxTask = tasks[taskId] else {
            // Try from persistence
            let persisted = DownloadPersistence.shared.loadAll()
            guard let record = persisted.first(where: { $0.taskId == taskId }) else { return false }
            // Re-create task with new URL
            _ = startDownload(url: newURL, fileName: record.fileName, headers: record.headers)
            DownloadPersistence.shared.remove(taskId: taskId)
            return true
        }

        dxTask.status = .idle
        dxTask.errorMessage = nil
        _ = startDownload(url: newURL, fileName: dxTask.fileName,
                          destinationPath: dxTask.destinationPath, headers: dxTask.headers)
        return true
    }

    /// Get all active/paused/queued tasks.
    public func getActiveTasks() -> [[String: Any]] {
        tasks.values.map { $0.toDict() }
    }

    /// Get list of all task IDs.
    public func allTaskIds() -> [String] {
        Array(tasks.keys)
    }

    /// Get download history from persistence.
    public func getHistory() -> [[String: Any]] {
        DownloadPersistence.shared.loadAll().map { record in
            var dict: [String: Any] = [
                "taskId": record.taskId,
                "url": record.url,
                "fileName": record.fileName,
                "destinationPath": record.destinationPath,
                "totalBytes": record.totalBytes,
                "receivedBytes": record.receivedBytes,
                "status": record.status,
                "createdAt": ISO8601DateFormatter().string(from: record.createdAt),
                "retryCount": record.retryCount,
                "category": record.category,
                "headers": record.headers as Any,
            ]
            if let completed = record.completedAt {
                dict["completedAt"] = ISO8601DateFormatter().string(from: completed)
            }
            return dict
        }
    }

    /// Clear download history, optionally deleting files.
    public func clearHistory(deleteFiles: Bool) {
        let all = DownloadPersistence.shared.loadAll()
        for record in all {
            if deleteFiles {
                try? FileManager.default.removeItem(atPath: record.destinationPath)
            }
        }
        DownloadPersistence.shared.saveAll([])
    }

    // MARK: - Queue Management

    public func getMaxConcurrent() -> Int {
        DownloadQueueManager.shared.maxConcurrent
    }

    public func setMaxConcurrent(_ count: Int) {
        DownloadQueueManager.shared.setMaxConcurrent(count)
    }

    // MARK: - Retry

    /// Retry a failed download with exponential backoff.
    public func retryDownload(taskId: String) {
        guard let dxTask = tasks[taskId], dxTask.status == .failed else { return }
        dxTask.retryCount += 1
        let delay = min(pow(2.0, Double(dxTask.retryCount)) * 2.0, 60.0) // 2, 4, 8, 16, 32, 60 max

        dxTask.status = .retrying
        broadcastUpdate(task: dxTask)
        persistTask(dxTask)
        logger.info("Retry \(dxTask.retryCount) for \(dxTask.fileName) in \(delay)s")

        retryTimers[taskId] = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            guard let task = self.tasks[taskId], task.status == .retrying else { return }
            guard let url = URL(string: task.url) else { return }
            self.beginDownload(task: task, url: url)
        }
    }

    // MARK: - Persistence Helper

    private func persistTask(_ task: DXDownloadTask) {
        let record = PersistedDownload(
            taskId: task.taskId,
            url: task.url,
            fileName: task.fileName,
            destinationPath: task.destinationPath,
            totalBytes: task.totalBytes,
            receivedBytes: task.receivedBytes,
            etag: task.etag,
            lastModified: "",
            status: task.statusString(),
            createdAt: task.createdAt,
            completedAt: task.completedAt,
            resumeData: task.resumeData,
            chunkPaths: [],
            headers: task.headers,
            retryCount: task.retryCount,
            category: task.category
        )
        DownloadPersistence.shared.upsert(record)
    }

    // MARK: - Progress Broadcasting

    private func broadcastUpdate(task: DXDownloadTask) {
        let dict = task.toDict()
        DispatchQueue.main.async { [weak self] in
            self?.onProgressUpdate?(dict)
        }
    }

    /// Returns a path inside the categorized Downloads structure managed by StorageManager.
    public static func defaultDestination(for fileName: String) -> String {
        let url = StorageManager.shared.destinationPath(for: fileName)
        return url.path
    }
}

// MARK: - URLSessionDownloadDelegate

extension BackgroundDownloader: URLSessionDownloadDelegate, @unchecked Sendable {

    public nonisolated func urlSession(_ session: URLSession,
                                       downloadTask: URLSessionDownloadTask,
                                       didFinishDownloadingTo location: URL) {
        Task {
            await handleFinished(downloadTask: downloadTask, location: location)
        }
    }

    private func handleFinished(downloadTask: URLSessionDownloadTask, location: URL) {
        guard let taskId = sessionTaskToTaskId[downloadTask.taskIdentifier],
              let dxTask = tasks[taskId] else { return }

        // If task was cancelled, don't save
        if dxTask.status == .cancelled { return }

        let destURL = URL(fileURLWithPath: dxTask.destinationPath)
        do {
            try FileManager.default.createDirectory(
                at: destURL.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.moveItem(at: location, to: destURL)

            dxTask.status = .completed
            dxTask.progress = 1.0
            dxTask.completedAt = Date()
            logger.info("Completed: \(taskId) -> \(dxTask.fileName)")
        } catch {
            dxTask.status = .failed
            dxTask.errorMessage = error.localizedDescription
            logger.error("Failed to move file: \(error)")
        }

        broadcastUpdate(task: dxTask)
        persistTask(dxTask)
        sessionTaskToTaskId.removeValue(forKey: downloadTask.taskIdentifier)
        DownloadQueueManager.shared.taskDidFinish(taskId: taskId)
    }

    public nonisolated func urlSession(_ session: URLSession,
                                       downloadTask: URLSessionDownloadTask,
                                       didWriteData bytesWritten: Int64,
                                       totalBytesWritten: Int64,
                                       totalBytesExpectedToWrite: Int64) {
        Task {
            await handleProgress(
                taskIdentifier: downloadTask.taskIdentifier,
                received: totalBytesWritten,
                total: totalBytesExpectedToWrite)
        }
    }

    private func handleProgress(taskIdentifier: Int, received: Int64, total: Int64) {
        guard let taskId = sessionTaskToTaskId[taskIdentifier],
              let dxTask = tasks[taskId] else { return }
        dxTask.recordProgress(receivedBytes: received, totalBytes: total)
        broadcastUpdate(task: dxTask)
        // Persist periodically (every 5% or every 2 seconds throttled by the broadcast)
    }

    public nonisolated func urlSession(_ session: URLSession,
                                       task: URLSessionTask,
                                       didCompleteWithError error: Error?) {
        guard let error else { return }
        Task {
            await handleError(taskIdentifier: task.taskIdentifier, error: error)
        }
    }

    private func handleError(taskIdentifier: Int, error: Error) {
        guard let taskId = sessionTaskToTaskId[taskIdentifier],
              let dxTask = tasks[taskId] else { return }

        let nsError = error as NSError

        // Check for resume data (paused by user)
        if let resumeData = nsError.userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
            dxTask.resumeData = resumeData
            dxTask.status = .paused
            persistTask(dxTask)
            broadcastUpdate(task: dxTask)
            return
        }

        // Check for cancellation
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            if dxTask.status == .cancelled { return }
            dxTask.status = .paused
            broadcastUpdate(task: dxTask)
            persistTask(dxTask)
            return
        }

        // Determine if we should retry
        let shouldRetry = dxTask.retryCount < maxRetries && isRetryable(nsError)

        if shouldRetry {
            dxTask.errorMessage = error.localizedDescription
            broadcastUpdate(task: dxTask)
            // Schedule automatic retry
            Task {
                await self.retryDownload(taskId: taskId)
            }
        } else {
            dxTask.status = .failed
            dxTask.errorMessage = error.localizedDescription
            logger.error("Download error: \(error.localizedDescription)")
            broadcastUpdate(task: dxTask)
            persistTask(dxTask)
            sessionTaskToTaskId.removeValue(forKey: taskIdentifier)
            DownloadQueueManager.shared.taskDidFinish(taskId: taskId)
        }
    }

    private func isRetryable(_ error: NSError) -> Bool {
        switch error.code {
        case NSURLErrorTimedOut,
             NSURLErrorNetworkConnectionLost,
             NSURLErrorNotConnectedToInternet,
             NSURLErrorCancelled:
            return true
        default:
            // Check for 5xx status codes (captured in the error description)
            if let description = error.userInfo[NSLocalizedDescriptionKey] as? String {
                if description.contains("5") || description.contains("503") || description.contains("502") {
                    return true
                }
            }
            return false
        }
    }

    public nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task { @MainActor in
            if let handler = (UIApplication.shared.delegate as? AppDelegate)?.backgroundCompletionHandler {
                handler()
            }
        }
    }
}
