import ActivityKit
import AppIntents
import Foundation

@available(iOS 17.0, *)
struct CompletePickupCodeIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "完成取码"
    static var description = IntentDescription("结束当前 BiuLand 实时活动。")

    func perform() async throws -> some IntentResult {
        for activity in Activity<PickupCodeActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        return .result()
    }
}
