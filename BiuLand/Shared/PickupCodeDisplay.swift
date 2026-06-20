import SwiftUI

struct PickupCodeDisplayModel: Hashable {
    let icon: String
    let brandIconName: String?
    let title: String
    let code: String
    let context: String
    let isPlaceholder: Bool

    var visibleContext: String {
        Self.visibleContext(for: context)
    }

    static func visibleContext(for context: String) -> String {
        hiddenContexts.contains(context) ? "" : context
    }

    static func completionTitle(for icon: String) -> String {
        icon == "shippingbox.fill" ? "已经取件" : "已经取餐"
    }

    private static let hiddenContexts: Set<String> = [
        "邻近行命中关键词",
        "快递取件码",
        "关键词旁码",
        "数字码型",
        "字母数字混合",
        "负向上下文"
    ]
}

extension PickupCodeDisplayModel {
    init(activityState state: PickupCodeActivityAttributes.ContentState) {
        self.init(
            icon: state.icon,
            brandIconName: state.brandIconName,
            title: state.brandName ?? "当前取码",
            code: state.code,
            context: state.context,
            isPlaceholder: false
        )
    }
}

struct PickupCodeIconView: View {
    let icon: String
    let brandIconName: String?
    let size: CGFloat
    let systemColor: Color
    let frameWidth: CGFloat?
    let brandShadowColor: Color?
    let brandOutlineColor: Color?

    init(
        icon: String,
        brandIconName: String?,
        size: CGFloat,
        systemColor: Color,
        frameWidth: CGFloat? = nil,
        brandShadowColor: Color? = nil,
        brandOutlineColor: Color? = nil
    ) {
        self.icon = icon
        self.brandIconName = brandIconName
        self.size = size
        self.systemColor = systemColor
        self.frameWidth = frameWidth
        self.brandShadowColor = brandShadowColor
        self.brandOutlineColor = brandOutlineColor
    }

    var body: some View {
        Group {
            if let brandIconName {
                outlinedBrandIcon(brandIconName)
            } else {
                Image(systemName: icon)
                    .font(.system(size: size, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(systemColor)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(width: frameWidth, alignment: .center)
    }

    @ViewBuilder
    private func outlinedBrandIcon(_ brandIconName: String) -> some View {
        let image = Image(brandIconName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)

        image
            .background {
                if let brandOutlineColor {
                    BrandIconOutline(
                        brandIconName: brandIconName,
                        size: size,
                        color: brandOutlineColor
                    )
                }
            }
            .clipShape(Circle())
            .shadow(color: brandShadowColor ?? .clear, radius: brandShadowColor == nil ? 0 : 4, y: brandShadowColor == nil ? 0 : 2)
    }
}

private struct BrandIconOutline: View {
    let brandIconName: String
    let size: CGFloat
    let color: Color

    var body: some View {
        ZStack {
            outlineLayer(x: -1.5, y: 0)
            outlineLayer(x: 1.5, y: 0)
            outlineLayer(x: 0, y: -1.5)
            outlineLayer(x: 0, y: 1.5)
            outlineLayer(x: -1, y: -1)
            outlineLayer(x: -1, y: 1)
            outlineLayer(x: 1, y: -1)
            outlineLayer(x: 1, y: 1)
        }
    }

    private func outlineLayer(x: CGFloat, y: CGFloat) -> some View {
        Image(brandIconName)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(color)
            .offset(x: x, y: y)
    }
}

struct PickupCodeTextBlock: View {
    let model: PickupCodeDisplayModel
    let codeSize: CGFloat
    let titleColor: Color
    let codeColor: Color
    let contextColor: Color
    let contextFont: Font
    let contextScale: CGFloat
    let spacing: CGFloat
    let showsTitle: Bool

    init(
        model: PickupCodeDisplayModel,
        codeSize: CGFloat,
        titleColor: Color = .secondary,
        codeColor: Color = .primary,
        contextColor: Color = .secondary,
        contextFont: Font = .caption2,
        contextScale: CGFloat = 0.75,
        spacing: CGFloat = 8,
        showsTitle: Bool = true
    ) {
        self.model = model
        self.codeSize = codeSize
        self.titleColor = titleColor
        self.codeColor = codeColor
        self.contextColor = contextColor
        self.contextFont = contextFont
        self.contextScale = contextScale
        self.spacing = spacing
        self.showsTitle = showsTitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            if showsTitle {
                Text(model.title)
                    .font(.caption)
                    .foregroundStyle(titleColor)
            }

            Text(model.isPlaceholder ? "----" : model.code)
                .font(.system(size: codeSize, weight: .heavy, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.38)
                .foregroundStyle(codeColor)

            if model.isPlaceholder == false && model.visibleContext.isEmpty == false {
                Text(model.visibleContext)
                    .font(contextFont)
                    .lineLimit(1)
                    .minimumScaleFactor(contextScale)
                    .foregroundStyle(contextColor)
            }
        }
    }
}
