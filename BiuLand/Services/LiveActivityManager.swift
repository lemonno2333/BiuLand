import Foundation
import ActivityKit

enum LiveActivityError: Error {
    case notAuthorized
}

final class LiveActivityManager {
    static let shared = LiveActivityManager()
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
            throw LiveActivityError.notAuthorized
        }

        var hasScreenshot = preserveExistingScreenshot && ScreenshotManager.shared.currentScreenshotExists()
        if let imageData = imageData {
            do {
                _ = try ScreenshotManager.shared.saveCurrentScreenshot(imageData)
                hasScreenshot = true
            } catch {
                print("Failed to save screenshot: \(error)")
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

        if let existing = Activity<PickupCodeActivityAttributes>.activities.first {
            await existing.update(
                ActivityContent(
                    state: state,
                    staleDate: Date().addingTimeInterval(PickupCodeHistoryStore.currentLifetime)
                )
            )
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
    }
}
