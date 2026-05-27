import Foundation
import ActivityKit

struct PickupCodeActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var code: String
        var context: String
        var icon: String
        var brandIconName: String?
        var brandName: String?
        var category: String?
        var confidence: Double
        var updatedAt: Date
    }

    var title: String
}
