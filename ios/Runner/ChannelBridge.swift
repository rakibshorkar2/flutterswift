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
