import Flutter
import UIKit
import OSLog

private let logger = Logger(subsystem: "com.dirxplorerakib.pro", category: "ChannelBridge")

/// Registers all Method/Event channels between Flutter and native Swift.
final class ChannelBridge: NSObject {

    // MARK: - Channels
    private let flutterEngine: FlutterEngine
    private var downloadProgressSink: FlutterEventSink?

    init(flutterEngine: FlutterEngine) {
        self.flutterEngine = flutterEngine
        super.init()
        setupDownloaderChannel()
        setupLiveActivityChannel()
        setupHapticsChannel()
        setupQuickLookChannel()
        setupFileChannel()
        setupStorageChannel()
        startMonitoring()
    }

    private func startMonitoring() {
        Task {
            // Check and run migration on first launch
            if await StorageManager.shared.needsMigration() {
                let count = await StorageManager.shared.runMigration()
                logger.info("Migrated \(count) files to categorized structure")
            }
            // Start Files app change monitoring
            await DirectoryMonitor.shared.startMonitoring()
            await DirectoryMonitor.shared.onChange = { _ in
                Task { @MainActor in
                    // Notify Flutter via event channel
                    self.fileEventSink?(["event": "directoryChanged"])
                }
            }
        }
    }

    // MARK: - Downloader Channel

    private func setupDownloaderChannel() {
        let messenger = flutterEngine.binaryMessenger

        let methodChannel = FlutterMethodChannel(
            name: "com.dirxplorerakib.pro/downloader",
            binaryMessenger: messenger
        )
        methodChannel.setMethodCallHandler { [weak self] call, result in
            Task {
                await self?.handleDownloaderMethod(call: call, result: result)
            }
        }

        let eventChannel = FlutterEventChannel(
            name: "com.dirxplorerakib.pro/downloader/progress",
            binaryMessenger: messenger
        )
        eventChannel.setStreamHandler(DownloadProgressHandler.shared)

        Task {
            await BackgroundDownloader.shared.configureProgressCallback { dict in
                DispatchQueue.main.async {
                    DownloadProgressHandler.shared.send(event: dict)
                }
            }
        }
    }

    @MainActor
    private func handleDownloaderMethod(call: FlutterMethodCall, result: @escaping FlutterResult) async {
        let args = call.arguments as? [String: Any]
        let downloader = BackgroundDownloader.shared

        switch call.method {
        // --- Existing methods ---
        case "startDownload":
            guard let url = args?["url"] as? String,
                  let fileName = args?["fileName"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "url and fileName required", details: nil))
                return
            }
            let taskId = await downloader.startDownload(
                url: url,
                fileName: fileName,
                destinationPath: args?["destinationPath"] as? String,
                headers: args?["headers"] as? [String: String]
            )
            result(taskId)

        case "pauseDownload":
            guard let taskId = args?["taskId"] as? String else { result(nil); return }
            await downloader.pauseDownload(taskId: taskId)
            result(nil)

        case "resumeDownload":
            guard let taskId = args?["taskId"] as? String else { result(nil); return }
            await downloader.resumeDownload(taskId: taskId)
            result(nil)

        case "cancelDownload":
            guard let taskId = args?["taskId"] as? String else { result(nil); return }
            await downloader.cancelDownload(taskId: taskId)
            result(nil)

        case "getActiveTasks":
            let tasks = await downloader.getActiveTasks()
            result(tasks)

        // --- New analysis method ---
        case "analyzeURL":
            guard let url = args?["url"] as? String else {
                result([:]); return
            }
            let meta = await downloader.analyzeURL(
                urlString: url,
                headers: args?["headers"] as? [String: String]
            )
            result(meta)

        // --- Retry ---
        case "retryDownload":
            guard let taskId = args?["taskId"] as? String else { result(nil); return }
            await downloader.retryDownload(taskId: taskId)
            result(nil)

        // --- Refresh with new URL ---
        case "refreshDownload":
            guard let taskId = args?["taskId"] as? String,
                  let newURL = args?["newURL"] as? String else {
                result(false); return
            }
            let success = await downloader.refreshDownload(taskId: taskId, newURL: newURL)
            result(success)

        // --- History ---
        case "getHistory":
            let history = await downloader.getHistory()
            result(history)

        case "clearHistory":
            let deleteFiles = args?["deleteFiles"] as? Bool ?? false
            await downloader.clearHistory(deleteFiles: deleteFiles)
            result(nil)

        // --- Queue / Concurrency ---
        case "getMaxConcurrent":
            let max = await downloader.getMaxConcurrent()
            result(max)

        case "setMaxConcurrent":
            let count = args?["count"] as? Int ?? 2
            await downloader.setMaxConcurrent(count)
            result(nil)

        case "allTaskIds":
            let ids = await downloader.allTaskIds()
            result(ids)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - File / Storage Channels

    private var fileEventSink: FlutterEventSink?

    private func setupFileChannel() {
        let messenger = flutterEngine.binaryMessenger

        let methodChannel = FlutterMethodChannel(
            name: "com.dirxplorerakib.pro/files",
            binaryMessenger: messenger
        )
        methodChannel.setMethodCallHandler { [weak self] call, result in
            Task { await self?.handleFileMethod(call: call, result: result) }
        }

        let eventChannel = FlutterEventChannel(
            name: "com.dirxplorerakib.pro/files/events",
            binaryMessenger: messenger
        )
        eventChannel.setStreamHandler(FileEventHandler.shared)
    }

    private func setupStorageChannel() {
        let channel = FlutterMethodChannel(
            name: "com.dirxplorerakib.pro/storage",
            binaryMessenger: flutterEngine.binaryMessenger
        )
        channel.setMethodCallHandler { [weak self] call, result in
            Task { await self?.handleStorageMethod(call: call, result: result) }
        }
    }

    @MainActor
    private func handleFileMethod(call: FlutterMethodCall, result: @escaping FlutterResult) async {
        let args = call.arguments as? [String: Any]
        let storage = StorageManager.shared

        switch call.method {
        case "listFiles":
            let files = storage.listFiles(in: storage.downloadsDirectory)
            result(files.map(encodeFileInfo))

        case "listFilesInCategory":
            guard let cat = args?["category"] as? String else { result([]); return }
            let dir = storage.categoryDirectory(cat)
            let files = storage.listFiles(in: dir)
            result(files.map(encodeFileInfo))

        case "searchFiles":
            let query = args?["query"] as? String ?? ""
            let files = await storage.searchFiles(query: query)
            result(files.map(encodeFileInfo))

        case "filesByCategory":
            let grouped = await storage.filesByCategory()
            let dict = grouped.mapValues { $0.map(encodeFileInfo) }
            result(dict)

        case "deleteFile":
            guard let path = args?["path"] as? String else { result(false); return }
            let success = await storage.deleteFile(at: path)
            result(success)

        case "renameFile":
            guard let path = args?["path"] as? String,
                  let newName = args?["newName"] as? String else { result(nil); return }
            let newPath = await storage.renameFile(at: path, to: newName)
            result(newPath)

        case "moveFile":
            guard let path = args?["path"] as? String,
                  let category = args?["category"] as? String else { result(nil); return }
            let newPath = await storage.moveFile(at: path, toCategory: category)
            result(newPath)

        case "importFile":
            guard let sourcePath = args?["sourcePath"] as? String else { result(nil); return }
            let sourceURL = URL(fileURLWithPath: sourcePath)
            let destPath = await storage.importFile(at: sourceURL)
            result(destPath)

        case "openDocumentPicker":
            // Trigger native document picker from the view controller
            await openDocumentPicker()

        case "needsMigration":
            let needed = await storage.needsMigration()
            result(needed)

        case "runMigration":
            let count = await storage.runMigration()
            result(count)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    @MainActor
    private func handleStorageMethod(call: FlutterMethodCall, result: @escaping FlutterResult) async {
        let storage = StorageManager.shared

        switch call.method {
        case "getStorageInfo":
            let info = await storage.getStorageInfo()
            result([
                "usedBytes": info.usedBytes,
                "freeDeviceBytes": info.freeDeviceBytes,
                "fileCount": info.fileCount,
                "folderCount": info.folderCount,
                "largestFiles": info.largestFiles.map(encodeFileInfo),
                "recentFiles": info.recentFiles.map(encodeFileInfo),
                "categoryCounts": info.categoryCounts,
            ])

        case "getDownloadsDirectory":
            result(storage.downloadsDirectory.path)

        case "getRootDirectory":
            result(storage.rootDirectory.path)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Helpers

    private func encodeFileInfo(_ f: FileInfo) -> [String: Any] {
        [
            "name": f.name,
            "path": f.path,
            "relativePath": f.relativePath,
            "extension": f.extension,
            "size": f.size,
            "formattedSize": f.formattedSize,
            "createdAt": ISO8601DateFormatter().string(from: f.createdAt),
            "modifiedAt": ISO8601DateFormatter().string(from: f.modifiedAt),
            "category": f.category,
            "isDirectory": f.isDirectory,
        ]
    }

    @MainActor
    private func openDocumentPicker() async {
        guard let vc = flutterEngine.viewController else { return }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.data], asCopy: true)
        picker.allowsMultipleSelection = true
        let delegate = DocumentPickerDelegate()
        picker.delegate = delegate
        vc.present(picker, animated: true)
        // Store delegate reference to keep it alive
        objc_setAssociatedObject(picker, "delegateKey", delegate, .OBJC_ASSOCIATION_RETAIN)
    }

    // MARK: - Live Activity Channel

    private func setupLiveActivityChannel() {
        let channel = FlutterMethodChannel(
            name: "com.dirxplorerakib.pro/live_activity",
            binaryMessenger: flutterEngine.binaryMessenger
        )
        channel.setMethodCallHandler { call, result in
            let args = call.arguments as? [String: Any]
            switch call.method {
            case "startActivity":
                if #available(iOS 16.1, *) {
                    LiveActivityManager.shared.startActivity(
                        taskId: args?["taskId"] as? String ?? "",
                        fileName: args?["fileName"] as? String ?? "",
                        progress: args?["progress"] as? Double ?? 0,
                        speed: args?["speed"] as? Double ?? 0,
                        eta: args?["eta"] as? Int ?? 0
                    )
                }
                result(nil)
            case "updateActivity":
                if #available(iOS 16.1, *) {
                    LiveActivityManager.shared.updateActivity(
                        taskId: args?["taskId"] as? String ?? "",
                        progress: args?["progress"] as? Double ?? 0,
                        speed: args?["speed"] as? Double ?? 0,
                        eta: args?["eta"] as? Int ?? 0,
                        status: args?["status"] as? String ?? ""
                    )
                }
                result(nil)
            case "endActivity":
                if #available(iOS 16.1, *) {
                    LiveActivityManager.shared.endActivity(
                        taskId: args?["taskId"] as? String ?? ""
                    )
                }
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    // MARK: - Haptics Channel

    private func setupHapticsChannel() {
        let channel = FlutterMethodChannel(
            name: "com.dirxplorerakib.pro/haptics",
            binaryMessenger: flutterEngine.binaryMessenger
        )
        channel.setMethodCallHandler { call, result in
            let args = call.arguments as? [String: Any]
            switch call.method {
            case "impact":
                let style = args?["style"] as? String ?? "medium"
                let feedback: UIImpactFeedbackGenerator
                switch style {
                case "light": feedback = UIImpactFeedbackGenerator(style: .light)
                case "heavy": feedback = UIImpactFeedbackGenerator(style: .heavy)
                default: feedback = UIImpactFeedbackGenerator(style: .medium)
                }
                feedback.impactOccurred()
            case "notification":
                let type = args?["type"] as? String ?? "success"
                let feedback = UINotificationFeedbackGenerator()
                switch type {
                case "warning": feedback.notificationOccurred(.warning)
                case "error": feedback.notificationOccurred(.error)
                default: feedback.notificationOccurred(.success)
                }
            case "selectionChanged":
                UISelectionFeedbackGenerator().selectionChanged()
            default:
                break
            }
            result(nil)
        }
    }

    // MARK: - QuickLook Channel

    private func setupQuickLookChannel() {
        let channel = FlutterMethodChannel(
            name: "com.dirxplorerakib.pro/quicklook",
            binaryMessenger: flutterEngine.binaryMessenger
        )
        channel.setMethodCallHandler { [weak self] call, result in
            let args = call.arguments as? [String: Any]
            guard let filePath = args?["filePath"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "filePath required", details: nil))
                return
            }
            switch call.method {
            case "preview":
                self?.presentQuickLook(filePath: filePath)
            case "openIn":
                self?.presentOpenIn(filePath: filePath)
            default:
                result(FlutterMethodNotImplemented)
                return
            }
            result(nil)
        }
    }

    @MainActor
    private func presentQuickLook(filePath: String) {
        let url = URL(fileURLWithPath: filePath)
        guard FileManager.default.fileExists(atPath: filePath) else {
            logger.error("QuickLook: file not found at \(filePath)")
            return
        }
        let vc = QuickLookViewController(fileURL: url)
        flutterEngine.viewController?.present(vc, animated: true)
    }

    @MainActor
    private func presentOpenIn(filePath: String) {
        let url = URL(fileURLWithPath: filePath)
        let dc = UIDocumentInteractionController(url: url)
        dc.presentOptionsMenu(from: .zero, in: flutterEngine.viewController?.view ?? UIView(), animated: true)
    }
}

// MARK: - Event Channel stream handler

final class DownloadProgressHandler: NSObject, FlutterStreamHandler {
    static let shared = DownloadProgressHandler()

    private var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    func send(event: [String: Any]) {
        eventSink?(event)
    }
}

// MARK: - File Event Handler

final class FileEventHandler: NSObject, FlutterStreamHandler {
    static let shared = FileEventHandler()

    private var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        // Register the sink so DirectoryMonitor can push events
        Task {
            await DirectoryMonitor.shared.onChange = { _ in
                events(["event": "directoryChanged"])
            }
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    func send(event: [String: Any]) {
        eventSink?(event)
    }
}

// MARK: - Document Picker Delegate

final class DocumentPickerDelegate: NSObject, UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        for url in urls {
            Task {
                let success = url.startAccessingSecurityScopedResource()
                defer { if success { url.stopAccessingSecurityScopedResource() } }
                _ = await StorageManager.shared.importFile(at: url)
            }
        }
        controller.dismiss(animated: true)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        controller.dismiss(animated: true)
    }
}
