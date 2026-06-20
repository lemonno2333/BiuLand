import ActivityKit
import AppIntents
import WidgetKit
import SwiftUI

struct LiveActivityLiveActivity: Widget {
    private let lightBrandOutline = Color.white.opacity(0.9)
    private let darkBrandOutline = Color.black.opacity(0.72)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PickupCodeActivityAttributes.self) { context in
            activityContent(for: PickupCodeDisplayModel(activityState: context.state))
                .padding(16)
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let display = PickupCodeDisplayModel(activityState: context.state)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    activityIcon(display, size: 64)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                DynamicIslandExpandedRegion(.center) {
                    PickupCodeTextBlock(
                        model: display,
                        codeSize: display.code.count > 4 ? 28 : 34,
                        contextScale: 0.7,
                        spacing: 5
                    )
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Spacer()
                        completionButton(for: display)
                    }
                }
            } compactLeading: {
                compactIcon(display, size: 24)
            } compactTrailing: {
                Text(display.code)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } minimal: {
                compactIcon(display, size: 20)
            }
        }
    }

    @ViewBuilder
    private func activityContent(for display: PickupCodeDisplayModel) -> some View {
        if display.code.count > 4 {
            HStack(spacing: 16) {
                activityIcon(display, size: 66)
                    .frame(maxHeight: .infinity, alignment: .center)

                VStack(alignment: .leading, spacing: 10) {
                    lockScreenCodeBlock(for: display, codeSize: 36)

                    HStack {
                        Spacer()
                        completionButton(for: display)
                    }
                }
            }
        } else {
            ZStack(alignment: .bottomTrailing) {
                HStack(spacing: 16) {
                    activityIcon(display, size: 66)
                    lockScreenCodeBlock(for: display, codeSize: 38)
                    Spacer(minLength: 0)
                }

                completionButton(for: display)
            }
        }
    }

    @ViewBuilder
    private func activityIcon(_ display: PickupCodeDisplayModel, size: CGFloat) -> some View {
        PickupCodeIconView(
            icon: display.icon,
            brandIconName: display.brandIconName,
            size: size,
            systemColor: .white,
            frameWidth: display.brandIconName == nil ? 76 : 84,
            brandOutlineColor: brandOutlineColor(forDarkBackground: true)
        )
    }

    @ViewBuilder
    private func compactIcon(_ display: PickupCodeDisplayModel, size: CGFloat) -> some View {
        PickupCodeIconView(
            icon: display.icon,
            brandIconName: display.brandIconName,
            size: size,
            systemColor: .primary,
            brandOutlineColor: brandOutlineColor(forDarkBackground: true)
        )
    }

    private func brandOutlineColor(forDarkBackground isDarkBackground: Bool) -> Color {
        isDarkBackground ? lightBrandOutline : darkBrandOutline
    }

    @ViewBuilder
    private func lockScreenCodeBlock(for display: PickupCodeDisplayModel, codeSize: CGFloat) -> some View {
        PickupCodeTextBlock(
            model: display,
            codeSize: codeSize,
            titleColor: .white.opacity(0.72),
            codeColor: .white,
            contextColor: .white.opacity(0.72)
        )
    }

    @ViewBuilder
    private func completionButton(for display: PickupCodeDisplayModel) -> some View {
        if #available(iOS 17.0, *) {
            Button(intent: CompletePickupCodeIntent()) {
                Label(PickupCodeDisplayModel.completionTitle(for: display.icon), systemImage: "checkmark.circle.fill")
                    .font(.caption.bold())
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white.opacity(0.16))
            .foregroundStyle(.white)
        }
    }
}
