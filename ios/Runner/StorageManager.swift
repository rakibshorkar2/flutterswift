import Foundation
import OSLog

private let logger = Logger(subsystem: "com.dirxplorerakib.pro", category: "StorageManager")

/// Centralized file system manager for all storage operations.
/// Uses the app's Documents directory as root, exposing content in Files app.
public actor StorageManager {

    public static let shared = StorageManager()

    // MARK: - Categories

    public static let categories: [String] = [
        "Movies", "TV Shows", "Music", "Images",
        "Documents", "Archives", "Applications", "Other"
    ]

    private static let categoryExtensions: [String: String] = {
        var map: [String: String] = [:]
        // Video
        for ext in ["mkv","mp4","avi","mov","wmv","flv","webm","m4v","ts","m2ts","3gp"] {
            map[ext] = "Movies"
        }
        // TV shows — by convention folders, not extension-based; default to Movies
        // Audio
        for ext in ["mp3","flac","wav","aac","ogg","wma","m4a","opus","alac","wv"] {
            map[ext] = "Music"
        }
        // Images
        for ext in ["jpg","jpeg","png","gif","bmp","webp","svg","heic","avif","tiff","ico"] {
            map[ext] = "Images"
        }
        // Documents
        for ext in ["pdf","doc","docx","xls","xlsx","ppt","pptx","txt","csv","rtf",
                     "md","json","xml","yaml","yml","log","cfg","conf"] {
            map[ext] = "Documents"
        }
        // Archives
        for ext in ["zip","rar","7z","tar","gz","bz2","xz","zst","tgz","zlib"] {
            map[ext] = "Archives"
        }
        // Applications
        for ext in ["ipa","apk","dmg","exe","msi","deb","rpm","appimage"] {
            map[ext] = "Applications"
        }
        // Disk images
        for ext in ["iso","img","vhd","vmdk"] {
            map[ext] = "Applications"
        }
        return map
    }()

    // MARK: - Paths

    private let fileManager = FileManager.default

    private init() {
        createStandardDirectories()
    }

    /// Root Documents/DirXplore Pro — visible in Files app
    public nonisolated var rootDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("DirXplore Pro", isDirectory: true)
    }

    /// Downloads subdirectory
    public nonisolated var downloadsDirectory: URL {
        rootDirectory.appendingPathComponent("Downloads", isDirectory: true)
    }

    /// Path for a specific category
    public nonisolated func categoryDirectory(_ category: String) -> URL {
        downloadsDirectory.appendingPathComponent(category, isDirectory: true)
    }

    /// Determine category from file extension
    public static func category(for fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        return categoryExtensions[ext] ?? "Other"
    }

    /// Full destination path for a file, creating category folder if needed
    public func destinationPath(for fileName: String) -> URL {
        let cat = Self.category(for: fileName)
        let dir = categoryDirectory(cat)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(fileName)
    }

    // MARK: - Directory Creation

    private func createStandardDirectories() {
        let dirs = [rootDirectory, downloadsDirectory] + Self.categories.map { categoryDirectory($0) }
        for dir in dirs {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    /// Ensure all standard directories exist (call on launch)
    public func ensureDirectories() {
        createStandardDirectories()
    }

    // MARK: - File Operations

    /// List all files in a directory recursively
    public func listFiles(in directory: URL) -> [FileInfo] {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .creationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var result: [FileInfo] = []
        for case let fileURL as URL in enumerator {
            guard let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path) else { continue }
            let isDir = (attrs[.type] as? FileAttributeType) == .typeDirectory
            guard !isDir else { continue }

            let fileSize = attrs[.size] as? Int64 ?? 0
            let modDate = attrs[.modificationDate] as? Date ?? Date()
            let created = attrs[.creationDate] as? Date ?? Date()
            let relPath = fileURL.path.replacingOccurrences(of: rootDirectory.path + "/", with: "")
            let ext = (fileURL.lastPathComponent as NSString).pathExtension.lowercased()
            let cat = Self.category(for: fileURL.lastPathComponent)

            result.append(FileInfo(
                name: fileURL.lastPathComponent,
                path: fileURL.path,
                relativePath: relPath,
                extension: ext,
                size: fileSize,
                createdAt: created,
                modifiedAt: modDate,
                category: cat,
                isDirectory: false
            ))
        }
        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Get files grouped by category
    public func filesByCategory() -> [String: [FileInfo]] {
        let all = listFiles(in: downloadsDirectory)
        var grouped: [String: [FileInfo]] = [:]
        for cat in Self.categories {
            grouped[cat] = all.filter { $0.category == cat }
        }
        grouped["Other"] = all.filter { !Self.categories.contains($0.category) }
        return grouped
    }

    /// Search files by name
    public func searchFiles(query: String) -> [FileInfo] {
        let all = listFiles(in: downloadsDirectory)
        guard !query.isEmpty else { return all }
        let q = query.lowercased()
        return all.filter { $0.name.lowercased().contains(q) || $0.extension.lowercased().contains(q) }
    }

    /// Delete a file
    public func deleteFile(at path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        guard fileManager.fileExists(atPath: path) else { return false }
        do {
            try fileManager.removeItem(at: url)
            logger.info("Deleted file: \(path)")
            return true
        } catch {
            logger.error("Failed to delete: \(error)")
            return false
        }
    }

    /// Rename a file
    public func renameFile(at path: String, to newName: String) -> String? {
        let url = URL(fileURLWithPath: path)
        let dir = url.deletingLastPathComponent()
        let dest = dir.appendingPathComponent(newName)
        guard !fileManager.fileExists(atPath: dest.path) else { return nil }
        do {
            try fileManager.moveItem(at: url, to: dest)
            logger.info("Renamed: \(path) -> \(dest.path)")
            return dest.path
        } catch {
            logger.error("Failed to rename: \(error)")
            return nil
        }
    }

    /// Move file to a new category directory
    public func moveFile(at path: String, toCategory category: String) -> String? {
        let url = URL(fileURLWithPath: path)
        let fileName = url.lastPathComponent
        let destDir = self.categoryDirectory(category)
        try? fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)
        let dest = resolveConflict(destDir.appendingPathComponent(fileName))
        do {
            try fileManager.moveItem(at: url, to: dest)
            logger.info("Moved: \(path) -> \(dest.path)")
            return dest.path
        } catch {
            logger.error("Failed to move: \(error)")
            return nil
        }
    }

    /// Copy a file into the appropriate category folder (for imports)
    public func importFile(at sourceURL: URL) -> String? {
        let fileName = sourceURL.lastPathComponent
        let dest = destinationPath(for: fileName)
        let resolved = resolveConflict(dest)
        do {
            try fileManager.copyItem(at: sourceURL, to: resolved)
            logger.info("Imported: \(resolved.path)")
            return resolved.path
        } catch {
            logger.error("Failed to import: \(error)")
            return nil
        }
    }

    // MARK: - Conflict Resolution

    /// If a file exists, append (n) before the extension
    public func resolveConflict(_ url: URL) -> URL {
        guard fileManager.fileExists(atPath: url.path) else { return url }
        let dir = url.deletingLastPathComponent()
        let name = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        var counter = 1
        while true {
            let newName = ext.isEmpty ? "\(name) (\(counter))" : "\(name) (\(counter)).\(ext)"
            let newURL = dir.appendingPathComponent(newName)
            if !fileManager.fileExists(atPath: newURL.path) {
                return newURL
            }
            counter += 1
        }
    }

    // MARK: - Storage Info

    public struct StorageInfo: Sendable, Codable {
        public let usedBytes: Int64
        public let fileCount: Int
        public let folderCount: Int
        public let freeDeviceBytes: Int64
        public let largestFiles: [FileInfo]
        public let recentFiles: [FileInfo]
        public let categoryCounts: [String: Int]
    }

    public func getStorageInfo() -> StorageInfo {
        let all = listFiles(in: downloadsDirectory)
        let usedBytes = all.reduce(0) { $0 + $1.size }
        let freeBytes = (try? fileManager.attributesOfFileSystem(forPath: rootDirectory.path))?[.systemFreeSize] as? Int64 ?? 0
        let largest = all.sorted { $0.size > $1.size }.prefix(10).map { $0 }
        let recent = all.sorted { $0.modifiedAt > $1.modifiedAt }.prefix(10).map { $0 }
        var catCounts: [String: Int] = [:]
        for cat in Self.categories { catCounts[cat] = all.filter { $0.category == cat }.count }
        catCounts["Other"] = all.filter { !Self.categories.contains($0.category) }.count

        return StorageInfo(
            usedBytes: usedBytes,
            fileCount: all.count,
            folderCount: Self.categories.count,
            freeDeviceBytes: freeBytes,
            largestFiles: largest,
            recentFiles: recent,
            categoryCounts: catCounts
        )
    }

    // MARK: - Migration

    /// Check if old downloads exist outside the standard structure
    public func needsMigration() -> Bool {
        // Check for files directly in DirXplore Pro root (not in Downloads/)
        let rootFiles = listFiles(in: rootDirectory).filter {
            !$0.relativePath.hasPrefix("Downloads/")
        }
        // Check for files in old flat location
        let oldDir = rootDirectory // legacy flat saves
        let oldFiles = (try? fileManager.contentsOfDirectory(at: oldDir, includingPropertiesForKeys: nil))
            ?? []
        return !rootFiles.isEmpty || oldFiles.contains { url in
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            return !isDir && !url.lastPathComponent.hasPrefix(".")
        }
    }

    /// Migrate files from old locations into categorized Downloads/
    public func runMigration() -> Int {
        var migratedCount = 0
        let rootFiles = (try? fileManager.contentsOfDirectory(at: rootDirectory, includingPropertiesForKeys: [.isDirectoryKey]))
            ?? []

        for url in rootFiles {
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            guard !isDir, !url.lastPathComponent.hasPrefix(".") else { continue }

            let fileName = url.lastPathComponent
            let dest = destinationPath(for: fileName)
            let resolved = resolveConflict(dest)
            do {
                try fileManager.moveItem(at: url, to: resolved)
                migratedCount += 1
                logger.info("Migrated: \(fileName) -> \(resolved.path)")
            } catch {
                logger.error("Migration failed for \(fileName): \(error)")
            }
        }
        return migratedCount
    }
}

// MARK: - FileInfo Model

public struct FileInfo: Sendable, Codable, Identifiable {
    public var id: String { path }
    public let name: String
    public let path: String
    public let relativePath: String
    public let `extension`: String
    public let size: Int64
    public let createdAt: Date
    public let modifiedAt: Date
    public let category: String
    public let isDirectory: Bool

    public var formattedSize: String {
        if size < 1024 { return "\(size) B" }
        if size < 1048576 { return String(format: "%.1f KB", Double(size) / 1024) }
        if size < 1073741824 { return String(format: "%.1f MB", Double(size) / 1048576) }
        return String(format: "%.2f GB", Double(size) / 1073741824)
    }

    public var fileExtension: String { `extension` }
}
