import Flutter
import UIKit
import OSLog

private let logger = Logger(subsystem: "com.dirxplorerakib.pro", category: "AppDelegate")

@main
@objc class AppDelegate: FlutterAppDelegate {

    /// Stored by the URLSession background download system; must be called when all events are delivered.
    var backgroundCompletionHandler: (() -> Void)?

    private var channelBridge: ChannelBridge?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // Wire Flutter engine
        let controller = window?.rootViewController as? FlutterViewController
        if let engine = controller?.engine {
            channelBridge = ChannelBridge(flutterEngine: engine)
        }

        // Initialise background downloader session
        Task {
            await BackgroundDownloader.shared.configure()
        }

        GeneratedPluginRegistrant.register(with: self)
        logger.info("DirXplore Pro launched")
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // MARK: - Background URLSession

    override func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        logger.info("Background URLSession events for: \(identifier)")
        backgroundCompletionHandler = completionHandler
    }
}
