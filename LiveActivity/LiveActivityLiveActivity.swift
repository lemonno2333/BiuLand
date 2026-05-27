import ActivityKit
import AppIntents
import WidgetKit
import SwiftUI

struct LiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PickupCodeActivityAttributes.self) { context in
            activityContent(for: context.state)
                .padding(16)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.icon)
                        .font(.system(size: 36, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 5) {
                        Text("当前取码")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(context.state.code)
                            .font(.system(size: context.state.code.count > 4 ? 28 : 34, weight: .heavy, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.42)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Spacer()
                        completionButton(for: context.state)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.icon)
                    .font(.system(size: 15, weight: .semibold))
            } compactTrailing: {
                Text(context.state.code)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } minimal: {
                Image(systemName: context.state.icon)
                    .font(.system(size: 13, weight: .semibold))
            }
        }
    }

    private func completionTitle(for icon: String) -> String {
        icon == "shippingbox.fill" ? "已经取件" : "已经取餐"
    }

    @ViewBuilder
    private func activityContent(for state: PickupCodeActivityAttributes.ContentState) -> some View {
        if state.code.count > 4 {
            HStack(spacing: 16) {
                activityIcon(state.icon)
                    .frame(maxHeight: .infinity, alignment: .center)

                VStack(alignment: .leading, spacing: 10) {
                    codeBlock(for: state, codeSize: 36)

                    HStack {
                        Spacer()
                        completionButton(for: state)
                    }
                }
            }
        } else {
            ZStack(alignment: .bottomTrailing) {
                HStack(spacing: 16) {
                    activityIcon(state.icon)
                    codeBlock(for: state, codeSize: 38)
                    Spacer(minLength: 0)
                }

                completionButton(for: state)
            }
        }
    }

    private func activityIcon(_ icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 52, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.white)
            .frame(width: 76, alignment: .center)
            .minimumScaleFactor(0.7)
    }

    private func codeBlock(for state: PickupCodeActivityAttributes.ContentState, codeSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("当前取码")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(state.code)
                .font(.system(size: codeSize, weight: .heavy, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.38)
        }
    }

    @ViewBuilder
    private func completionButton(for state: PickupCodeActivityAttributes.ContentState) -> some View {
        if #available(iOS 17.0, *) {
            Button(intent: CompletePickupCodeIntent()) {
                Label(completionTitle(for: state.icon), systemImage: "checkmark.circle.fill")
                    .font(.caption.bold())
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white.opacity(0.16))
            .foregroundStyle(.white)
        }
    }
}
