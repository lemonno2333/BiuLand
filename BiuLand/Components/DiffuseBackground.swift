import SwiftUI

struct DiffuseBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let theta = t * 0.12

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let isDark = colorScheme == .dark

                let p1x = -w * 0.14 + CGFloat(cos(theta * 0.86) * w * 0.04)
                let p1y = -h * 0.22 + CGFloat(sin(theta * 0.74) * h * 0.03)
                let p2x = w * 0.02 + CGFloat(sin(theta * 0.68 + 1.4) * w * 0.05)
                let p2y = h * 0.18 + CGFloat(cos(theta * 0.72 + 0.6) * h * 0.04)
                let p3x = w * 0.30 + CGFloat(cos(theta * 0.91 + 2.0) * w * 0.04)
                let p3y = h * 0.30 + CGFloat(sin(theta * 0.82 + 0.2) * h * 0.04)
                let p4x = -w * 0.28 + CGFloat(sin(theta * 0.58 + 2.5) * w * 0.03)
                let p4y = h * 0.48 + CGFloat(cos(theta * 0.62 + 1.3) * h * 0.03)

                ZStack {
                    LinearGradient(
                        colors: isDark
                            ? [
                                Color(red: 0.08, green: 0.09, blue: 0.15),
                                Color(red: 0.10, green: 0.10, blue: 0.18),
                                Color(red: 0.10, green: 0.09, blue: 0.15)
                            ]
                            : [
                                Color(red: 0.93, green: 0.95, blue: 0.995),
                                Color(red: 0.96, green: 0.93, blue: 0.975),
                                Color(red: 0.98, green: 0.92, blue: 0.95)
                            ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: isDark
                                    ? [
                                        Color(red: 0.50, green: 0.57, blue: 0.95).opacity(0.30),
                                        Color(red: 0.42, green: 0.50, blue: 0.88).opacity(0.14),
                                        Color.clear
                                    ]
                                    : [
                                        Color(red: 0.72, green: 0.78, blue: 1.0).opacity(0.66),
                                        Color(red: 0.82, green: 0.86, blue: 1.0).opacity(0.30),
                                        Color.clear
                                    ],
                                center: .center,
                                startRadius: 0,
                                endRadius: max(w, h) * 0.92
                            )
                        )
                        .frame(width: w * 1.48, height: h * 0.86)
                        .offset(x: p1x, y: p1y)
                        .blur(radius: 34)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: isDark
                                    ? [
                                        Color(red: 0.96, green: 0.56, blue: 0.72).opacity(0.24),
                                        Color(red: 0.80, green: 0.44, blue: 0.76).opacity(0.12),
                                        Color.clear
                                    ]
                                    : [
                                        Color(red: 0.98, green: 0.73, blue: 0.83).opacity(0.72),
                                        Color(red: 0.99, green: 0.82, blue: 0.88).opacity(0.32),
                                        Color.clear
                                    ],
                                center: .center,
                                startRadius: 0,
                                endRadius: max(w, h) * 0.96
                            )
                        )
                        .frame(width: w * 1.52, height: h * 1.00)
                        .offset(x: p2x, y: p2y)
                        .blur(radius: 40)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: isDark
                                    ? [
                                        Color(red: 0.48, green: 0.67, blue: 0.96).opacity(0.22),
                                        Color(red: 0.42, green: 0.57, blue: 0.90).opacity(0.10),
                                        Color.clear
                                    ]
                                    : [
                                        Color(red: 0.76, green: 0.79, blue: 1.0).opacity(0.54),
                                        Color(red: 0.86, green: 0.88, blue: 1.0).opacity(0.22),
                                        Color.clear
                                    ],
                                center: .center,
                                startRadius: 0,
                                endRadius: max(w, h) * 0.76
                            )
                        )
                        .frame(width: w * 1.18, height: h * 0.84)
                        .offset(x: p3x, y: p3y)
                        .blur(radius: 28)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: isDark
                                    ? [
                                        Color(red: 0.90, green: 0.64, blue: 0.54).opacity(0.18),
                                        Color(red: 0.78, green: 0.54, blue: 0.50).opacity(0.08),
                                        Color.clear
                                    ]
                                    : [
                                        Color(red: 1.0, green: 0.84, blue: 0.82).opacity(0.38),
                                        Color(red: 1.0, green: 0.90, blue: 0.88).opacity(0.16),
                                        Color.clear
                                    ],
                                center: .center,
                                startRadius: 0,
                                endRadius: max(w, h) * 0.68
                            )
                        )
                        .frame(width: w * 1.04, height: h * 0.76)
                        .offset(x: p4x, y: p4y)
                        .blur(radius: 30)

                    LinearGradient(
                        colors: isDark
                            ? [
                                Color.white.opacity(0.02),
                                Color.clear,
                                Color(red: 0.94, green: 0.78, blue: 0.88).opacity(0.04)
                            ]
                            : [
                                Color.white.opacity(0.26),
                                Color.clear,
                                Color(red: 0.97, green: 0.82, blue: 0.90).opacity(0.14)
                            ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .saturation(isDark ? 1.0 : 1.02)
                .ignoresSafeArea()
            }
        }
    }
}
