import ActivityKit
import AppIntents
import Foundation

@available(iOS 17.0, *)
struct CompletePickupCodeIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "完成取码"
    static var description = IntentDescription("结束当前 BiuLand 实时活动。")
    static var isDiscoverable: Bool = false
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        for activity in Activity<PickupCodeActivityAttributes>.activities {
            await activity.end(
                ActivityContent(state: activity.content.state, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }

        return .result()
    }
}
