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
                    activityIcon(context.state.icon, brandIconName: context.state.brandIconName, size: 64)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                DynamicIslandExpandedRegion(.center) {
                    let visibleContext = visiblePickupContext(context.state.context)
                    VStack(spacing: 5) {
                        Text(context.state.brandName ?? "当前取码")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(context.state.code)
                            .font(.system(size: context.state.code.count > 4 ? 28 : 34, weight: .heavy, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.42)
                        if visibleContext.isEmpty == false {
                            Text(visibleContext)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Spacer()
                        completionButton(for: context.state)
                    }
                }
            } compactLeading: {
                compactIcon(context.state.icon, brandIconName: context.state.brandIconName, size: 24)
            } compactTrailing: {
                Text(context.state.code)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } minimal: {
                compactIcon(context.state.icon, brandIconName: context.state.brandIconName, size: 20)
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
                activityIcon(state.icon, brandIconName: state.brandIconName, size: 66)
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
                    activityIcon(state.icon, brandIconName: state.brandIconName, size: 66)
                    codeBlock(for: state, codeSize: 38)
                    Spacer(minLength: 0)
                }

                completionButton(for: state)
            }
        }
    }

    @ViewBuilder
    private func activityIcon(_ icon: String, brandIconName: String?, size: CGFloat) -> some View {
        if let brandIconName {
            Image(brandIconName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .frame(width: 84, alignment: .center)
        } else {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
                .frame(width: 76, alignment: .center)
                .minimumScaleFactor(0.7)
        }
    }

    @ViewBuilder
    private func compactIcon(_ icon: String, brandIconName: String?, size: CGFloat) -> some View {
        if let brandIconName {
            Image(brandIconName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
        }
    }

    @ViewBuilder
    private func codeBlock(for state: PickupCodeActivityAttributes.ContentState, codeSize: CGFloat) -> some View {
        let visibleContext = visiblePickupContext(state.context)

        VStack(alignment: .leading, spacing: 8) {
            Text(state.brandName ?? "当前取码")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(state.code)
                .font(.system(size: codeSize, weight: .heavy, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.38)
            if visibleContext.isEmpty == false {
                Text(visibleContext)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(.secondary)
            }
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

    private func visiblePickupContext(_ context: String) -> String {
        let internalReasons = ["邻近行命中关键词", "快递取件码", "关键词旁码", "数字码型", "字母数字混合", "负向上下文"]
        return internalReasons.contains(context) ? "" : context
    }
}
