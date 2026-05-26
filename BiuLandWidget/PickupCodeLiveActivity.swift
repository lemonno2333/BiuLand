import ActivityKit
import WidgetKit
import SwiftUI

struct PickupCodeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PickupCodeActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                Text("当前取码")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(context.state.code)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text(context.state.context)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 6) {
                        Text("取码")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(context.state.code)
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                    }
                }
            } compactLeading: {
                Text("码")
            } compactTrailing: {
                Text(context.state.code)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            } minimal: {
                Text(String(context.state.code.prefix(1)))
            }
        }
    }
}
