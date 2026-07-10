import ActivityKit
import Foundation

// MARK: - Live Activity Attributes

/// ActivityKit attributes for the download Live Activity.
@available(iOS 16.1, *)
public struct DXDownloadAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var fileName: String
        public var progress: Double   // 0.0 – 1.0
        public var speedBytesPerSec: Double
        public var etaSeconds: Int
        public var status: String     // "downloading" | "paused" | "completed"

        public var formattedSpeed: String {
            if speedBytesPerSec < 1_024 { return "\(Int(speedBytesPerSec)) B/s" }
            if speedBytesPerSec < 1_048_576 { return String(format: "%.1f KB/s", speedBytesPerSec / 1_024) }
            return String(format: "%.1f MB/s", speedBytesPerSec / 1_048_576)
        }

        public var formattedEta: String {
            if etaSeconds <= 0 { return "--" }
            if etaSeconds < 60 { return "\(etaSeconds)s" }
            if etaSeconds < 3_600 { return "\(etaSeconds / 60)m \(etaSeconds % 60)s" }
            return "\(etaSeconds / 3_600)h \((etaSeconds % 3_600) / 60)m"
        }
    }

    public var taskId: String
    public init(taskId: String) { self.taskId = taskId }
}

// MARK: - Live Activity Manager

/// Manages ActivityKit sessions for download Live Activities.
@available(iOS 16.1, *)
public final class LiveActivityManager {
    public static let shared = LiveActivityManager()
    private var activities: [String: Activity<DXDownloadAttributes>] = [:]

    private init() {}

    public func startActivity(taskId: String,
                               fileName: String,
                               progress: Double,
                               speed: Double,
                               eta: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = DXDownloadAttributes(taskId: taskId)
        let contentState = DXDownloadAttributes.ContentState(
            fileName: fileName,
            progress: progress,
            speedBytesPerSec: speed,
            etaSeconds: eta,
            status: "downloading"
        )

        do {
            let activity = try Activity<DXDownloadAttributes>.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil),
                pushType: nil
            )
            activities[taskId] = activity
        } catch {
            // Live Activities not available or limit reached
        }
    }

    public func updateActivity(taskId: String,
                                progress: Double,
                                speed: Double,
                                eta: Int,
                                status: String) {
        guard let activity = activities[taskId] else { return }
        let contentState = DXDownloadAttributes.ContentState(
            fileName: activity.content.state.fileName,
            progress: progress,
            speedBytesPerSec: speed,
            etaSeconds: eta,
            status: status
        )
        Task {
            await activity.update(.init(state: contentState, staleDate: nil))
        }
    }

    public func endActivity(taskId: String) {
        guard let activity = activities[taskId] else { return }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            activities.removeValue(forKey: taskId)
        }
    }
}
