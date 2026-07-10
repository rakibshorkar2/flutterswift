import Foundation
import OSLog

private let logger = Logger(subsystem: "com.dirxplorerakib.pro", category: "DownloadPersistence")

/// A persisted download record that survives app restarts.
public struct PersistedDownload: Codable, Sendable {
    public let taskId: String
    public let url: String
    public let fileName: String
    public let destinationPath: String
    public var totalBytes: Int64
    public var receivedBytes: Int64
    public var etag: String
    public var lastModified: String
    public var status: String        // queued, downloading, paused, completed, failed, cancelled
    public var createdAt: Date
    public var completedAt: Date?
    public var resumeData: Data?     // serialized resume data for paused tasks
    public var chunkPaths: [String]  // paths for partial chunk files during multi-chunk download
    public var headers: [String: String]?
    public var retryCount: Int
    public var category: String     // video, audio, archive, document, image, app, other
}

/// Saves and loads download metadata to/from the app's documents directory as JSON.
public actor DownloadPersistence {

    public static let shared = DownloadPersistence()

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var dbURL: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dbDir = docs.appendingPathComponent(".downloads_db", isDirectory: true)
        try? fileManager.createDirectory(at: dbDir, withIntermediateDirectories: true)
        return dbDir.appendingPathComponent("downloads.json")
    }

    private init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    /// Load all persisted downloads.
    public func loadAll() -> [PersistedDownload] {
        guard fileManager.fileExists(atPath: dbURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: dbURL)
            return try decoder.decode([PersistedDownload].self, from: data)
        } catch {
            logger.error("Failed to load downloads: \(error)")
            return []
        }
    }

    /// Save all downloads to disk.
    public func saveAll(_ downloads: [PersistedDownload]) {
        do {
            let data = try encoder.encode(downloads)
            try data.write(to: dbURL, options: .atomic)
        } catch {
            logger.error("Failed to save downloads: \(error)")
        }
    }

    /// Append or replace a single download record.
    public func upsert(_ download: PersistedDownload) {
        var all = loadAll()
        if let idx = all.firstIndex(where: { $0.taskId == download.taskId }) {
            all[idx] = download
        } else {
            all.append(download)
        }
        saveAll(all)
    }

    /// Remove a download by taskId.
    public func remove(taskId: String) {
        let all = loadAll().filter { $0.taskId != taskId }
        saveAll(all)
    }

    /// Remove completed or failed downloads older than the given date.
    public func prune(olderThan date: Date) {
        let all = loadAll().filter { dl in
            guard let completed = dl.completedAt else { return true }
            return completed > date
        }
        saveAll(all)
    }

    /// List all taskIds.
    public func allTaskIds() -> [String] {
        loadAll().map(\.taskId)
    }
}
