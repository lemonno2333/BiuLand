import Foundation
import ActivityKit
import os

enum LiveActivityError: LocalizedError {
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "实时活动未开启，请在系统设置中允许 BiuLand 使用实时活动。"
        }
    }
}

final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private let logger = Logger(subsystem: "com.leo.BiuLand", category: "liveActivity")
    private init() {}

    @MainActor
    var hasActiveActivities: Bool {
        Activity<PickupCodeActivityAttributes>.activities.isEmpty == false
    }

    @MainActor
    func upsert(code: String, context: String, confidence: Double) async throws -> CurrentPickupCodeItem {
        try await upsert(code: code, context: context, icon: "fork.knife", confidence: confidence)
    }

    @MainActor
    func upsert(
        code: String,
        context: String,
        icon: String,
        brandIconName: String? = nil,
        brandName: String? = nil,
        category: PickupCategory? = nil,
        confidence: Double,
        imageData: Data? = nil,
        preserveExistingScreenshot: Bool = false
    ) async throws -> CurrentPickupCodeItem {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.warning("Live Activity authorization is disabled.")
            throw LiveActivityError.notAuthorized
        }

        var hasScreenshot = preserveExistingScreenshot && ScreenshotManager.shared.currentScreenshotExists()
        if let imageData = imageData {
            do {
                _ = try ScreenshotManager.shared.saveCurrentScreenshot(imageData)
                hasScreenshot = true
            } catch {
                logger.error("Failed to save current screenshot: \(error.localizedDescription, privacy: .public)")
            }
        } else if preserveExistingScreenshot == false {
            ScreenshotManager.shared.deleteCurrentScreenshot()
        }

        let state = PickupCodeActivityAttributes.ContentState(
            code: code,
            context: context,
            icon: icon,
            brandIconName: brandIconName,
            brandName: brandName,
            category: category?.rawValue,
            confidence: confidence,
            hasScreenshot: hasScreenshot,
            updatedAt: Date()
        )

        do {
            if let existing = Activity<PickupCodeActivityAttributes>.activities.first {
                await existing.update(
                    ActivityContent(
                        state: state,
                        staleDate: Date().addingTimeInterval(PickupCodeHistoryStore.currentLifetime)
                    )
                )
                logger.debug("Updated Live Activity for code \(code, privacy: .private(mask: .hash)).")
            } else {
                let attributes = PickupCodeActivityAttributes(title: "取码助手")
                _ = try Activity.request(
                    attributes: attributes,
                    content: ActivityContent(
                        state: state,
                        staleDate: Date().addingTimeInterval(PickupCodeHistoryStore.currentLifetime)
                    ),
                    pushType: nil
                )
                logger.debug("Requested Live Activity for code \(code, privacy: .private(mask: .hash)).")
            }
        } catch {
            logger.error("Failed to upsert Live Activity: \(error.localizedDescription, privacy: .public)")
            throw error
        }

        return PickupCodeHistoryStore.saveCurrent(
            code: code,
            context: context,
            icon: icon,
            brandIconName: brandIconName,
            brandName: brandName,
            category: category,
            confidence: confidence,
            hasScreenshot: hasScreenshot
        )
    }

    @MainActor
    func endAll() async {
        for activity in Activity<PickupCodeActivityAttributes>.activities {
            await activity.end(
                ActivityContent(state: activity.content.state, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
        logger.debug("Ended all Live Activities.")
    }
}
