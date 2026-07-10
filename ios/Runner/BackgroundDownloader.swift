import Foundation
import OSLog

private let logger = Logger(subsystem: "com.dirxplorerakib.pro", category: "BackgroundDownloader")

/// Represents the state of a single download task.
@objc public enum DXDownloadStatus: Int {
    case queued, downloading, paused, completed, failed, cancelled
}

/// Thread-safe model for a download task.
@objc public class DXDownloadTask: NSObject {
    @objc public let taskId: String
    @objc public let url: String
    @objc public let fileName: String
    @objc public let destinationPath: String
    @objc public var status: DXDownloadStatus = .queued
    @objc public var progress: Double = 0.0
    @objc public var speedBytesPerSec: Double = 0.0
    @objc public var etaSeconds: Int = 0
    @objc public var totalBytes: Int64 = 0
    @objc public var receivedBytes: Int64 = 0
    @objc public var resumeData: Data?
    @objc public var errorMessage: String?
    @objc public let createdAt: Date

    private var speedSamples: [(date: Date, bytes: Int64)] = []

    public init(taskId: String, url: String, fileName: String, destinationPath: String) {
        self.taskId = taskId
        self.url = url
        self.fileName = fileName
        self.destinationPath = destinationPath
        self.createdAt = Date()
    }

    /// Update speed using a moving average of the last 5 seconds.
    public func recordProgress(receivedBytes: Int64, totalBytes: Int64) {
        self.receivedBytes = receivedBytes
        self.totalBytes = totalBytes
        self.progress = totalBytes > 0 ? Double(receivedBytes) / Double(totalBytes) : 0

        let now = Date()
        speedSamples.append((date: now, bytes: receivedBytes))
        // Keep only samples within the last 3 seconds
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
        case .queued: return "queued"
        case .downloading: return "downloading"
        case .paused: return "paused"
        case .completed: return "completed"
        case .failed: return "failed"
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
        ]
        if let err = errorMessage { dict["errorMessage"] = err }
        return dict
    }
}

/// Manages URLSession background downloads with pause/resume support.
/// This actor serializes all mutations to prevent data races (Swift 6).
public actor BackgroundDownloader: NSObject {
    public static let shared = BackgroundDownloader()

    private static let sessionId = "com.dirxplorerakib.pro.bgdownload"

    private var urlSession: URLSession!
    private var tasks: [String: DXDownloadTask] = [:]
    private var sessionTaskToTaskId: [Int: String] = [:]

    // Called from main thread when progress events happen.
    public var onProgressUpdate: (([String: Any]) -> Void)?

    private override init() {}

    public func configure() {
        let config = URLSessionConfiguration.background(withIdentifier: Self.sessionId)
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.allowsCellularAccess = true
        config.waitsForConnectivity = true
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    /// Register a callback to receive progress updates. Called by ChannelBridge.
    public func configureProgressCallback(_ callback: @escaping ([String: Any]) -> Void) {
        onProgressUpdate = callback
    }

    /// Start a new download. Returns the task ID.
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
        tasks[taskId] = task

        var request = URLRequest(url: url)
        headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let sessionTask = urlSession.downloadTask(with: request)
        sessionTaskToTaskId[sessionTask.taskIdentifier] = taskId
        task.status = .downloading
        sessionTask.resume()

        logger.info("Started download: \(taskId) -> \(urlString)")
        return taskId
    }

    public func pauseDownload(taskId: String) {
        guard let dxTask = tasks[taskId] else { return }
        guard let sessionTaskId = sessionTaskToTaskId.first(where: { $0.value == taskId })?.key else { return }

        urlSession.getAllTasks { [weak self] sessionTasks in
            Task {
                await self?.doPause(sessionTasks: sessionTasks,
                                   sessionTaskId: sessionTaskId,
                                   dxTask: dxTask)
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
        broadcastUpdate(task: dxTask)
    }

    private func saveResumeData(_ data: Data?, for taskId: String) {
        tasks[taskId]?.resumeData = data
    }

    public func resumeDownload(taskId: String) {
        guard let dxTask = tasks[taskId], dxTask.status == .paused else { return }

        let sessionTask: URLSessionDownloadTask
        if let resumeData = dxTask.resumeData {
            sessionTask = urlSession.downloadTask(withResumeData: resumeData)
        } else {
            guard let url = URL(string: dxTask.url) else { return }
            sessionTask = urlSession.downloadTask(with: url)
        }
        sessionTaskToTaskId[sessionTask.taskIdentifier] = taskId
        dxTask.status = .downloading
        dxTask.resumeData = nil
        sessionTask.resume()
    }

    public func cancelDownload(taskId: String) {
        guard let dxTask = tasks[taskId] else { return }
        guard let sessionTaskId = sessionTaskToTaskId.first(where: { $0.value == taskId })?.key else {
            dxTask.status = .cancelled
            return
        }
        urlSession.getAllTasks { sessionTasks in
            sessionTasks.first(where: { $0.taskIdentifier == sessionTaskId })?.cancel()
        }
        dxTask.status = .cancelled
        tasks.removeValue(forKey: taskId)
        broadcastUpdate(task: dxTask)
    }

    public func getActiveTasks() -> [[String: Any]] {
        tasks.values.map { $0.toDict() }
    }

    private func broadcastUpdate(task: DXDownloadTask) {
        let dict = task.toDict()
        DispatchQueue.main.async { [weak self] in
            self?.onProgressUpdate?(dict)
        }
    }

    /// Returns a path inside Documents/DirXplore/ so files appear under the app's
    /// folder in the Files app ("On My iPhone" → "DirXplore Pro").
    private static func defaultDestination(for fileName: String) -> String {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let appFolder = docs.appendingPathComponent("DirXplore", isDirectory: true)
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        return appFolder.appendingPathComponent(fileName).path
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
            logger.info("Completed: \(taskId)")
        } catch {
            dxTask.status = .failed
            dxTask.errorMessage = error.localizedDescription
            logger.error("Failed to move file: \(error)")
        }
        broadcastUpdate(task: dxTask)
        sessionTaskToTaskId.removeValue(forKey: downloadTask.taskIdentifier)
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

        // Check for resume data (paused by user — not a true error)
        let nsError = error as NSError
        if let resumeData = nsError.userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
            dxTask.resumeData = resumeData
            dxTask.status = .paused
        } else {
            dxTask.status = .failed
            dxTask.errorMessage = error.localizedDescription
            logger.error("Download error: \(error)")
        }
        broadcastUpdate(task: dxTask)
    }

    public nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task { @MainActor in
            if let handler = (UIApplication.shared.delegate as? AppDelegate)?.backgroundCompletionHandler {
                handler()
            }
        }
    }
}
