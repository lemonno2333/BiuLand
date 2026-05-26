import Foundation
import ActivityKit

enum LiveActivityError: Error {
    case notAuthorized
}

final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private init() {}

    @MainActor
    func upsert(code: String, context: String, confidence: Double) async throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw LiveActivityError.notAuthorized
        }

        let state = PickupCodeActivityAttributes.ContentState(
            code: code,
            context: context,
            confidence: confidence,
            updatedAt: Date()
        )

        if let existing = Activity<PickupCodeActivityAttributes>.activities.first {
            await existing.update(
                ActivityContent(
                    state: state,
                    staleDate: Calendar.current.date(byAdding: .hour, value: 1, to: Date())
                )
            )
            return
        }

        let attributes = PickupCodeActivityAttributes(title: "取码助手")
        _ = try Activity.request(
            attributes: attributes,
            content: ActivityContent(
                state: state,
                staleDate: Calendar.current.date(byAdding: .hour, value: 1, to: Date())
            ),
            pushType: nil
        )
    }

    @MainActor
    func endAll() async {
        for activity in Activity<PickupCodeActivityAttributes>.activities {
            await activity.end(dismissalPolicy: .immediate)
        }
    }
}
