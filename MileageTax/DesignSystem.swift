//
//  DesignSystem.swift
//  MileageTax — Tokens + shared components matching "UI Concepts/".
//

import SwiftUI

enum DS {
    static let bg        = Color(hex: "#05090D")
    static let card      = Color(hex: "#0D1620")
    static let card2     = Color(hex: "#111C27")
    static let stroke    = Color.white.opacity(0.09)
    static let cyan      = Color(hex: "#19D8F5")
    static let green     = Color(hex: "#22E39A")
    static let amber     = Color(hex: "#FFB020")
    static let danger    = Color(hex: "#F0453A")
    static let text2     = Color.white.opacity(0.68)
    static let text3     = Color.white.opacity(0.42)
    static let brandGradient = LinearGradient(colors: [cyan, green], startPoint: .topLeading, endPoint: .bottomTrailing)
}

/// Scenic artwork for forms and sheets, faded before it reaches the controls.
struct ScenicScreenBackground: View {
    let image: String

    var body: some View {
        ScenicBackdrop(style: .mountainLake, showRoad: false, vignette: false, photo: image)
            .overlay {
                LinearGradient(stops: [
                    .init(color: DS.bg.opacity(0.38), location: 0),
                    .init(color: DS.bg.opacity(0.48), location: 0.25),
                    .init(color: DS.bg.opacity(0.9), location: 0.52),
                    .init(color: DS.bg, location: 0.78)
                ], startPoint: .top, endPoint: .bottom)
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

// MARK: - Typography

extension DS {
    /// Headlines and big numbers.
    static func display(_ size: CGFloat) -> Font { .custom("SpaceGrotesk-Bold", size: size, relativeTo: .title) }
    /// Uppercase labels, stats and units.
    static func tech(_ size: CGFloat) -> Font { .custom("ChakraPetch-Bold", size: size, relativeTo: .caption) }
}

/// The app icon (Assets › AppLogo, cut from AppIcon) used as the brand mark everywhere.
struct AppLogo: View {
    var size: CGFloat = 32
    var body: some View {
        Image("AppLogo")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous))
            .accessibilityLabel("MileageTax")
    }
}

// MARK: - Typography helpers

/// "EVERY MILE" white + "MEANS MONEY" accent, the headline pattern used on every onboarding slide.
struct TwoToneTitle: View {
    let first: String
    let second: String
    var accent: Color = DS.cyan
    var size: CGFloat = 30
    var alignment: TextAlignment = .center

    var body: some View {
        (Text(first + "\n").foregroundStyle(.white)
         + Text(second).foregroundStyle(LinearGradient(colors: [accent, accent == DS.cyan ? DS.green : DS.cyan],
                                                       startPoint: .leading, endPoint: .trailing)))
            .font(DS.display(size))
            .multilineTextAlignment(alignment)
            .lineSpacing(0)
            .shadow(color: .black.opacity(0.6), radius: 8, y: 2)
    }
}

/// "Mileage" (white) + "Tax" (cyan) wordmark.
struct Wordmark: View {
    var size: CGFloat = 20
    var body: some View {
        (Text("Mileage").foregroundStyle(.white) + Text("Tax").foregroundStyle(DS.brandGradient))
            .font(DS.display(size))
    }
}

// MARK: - Buttons

struct DSPrimaryButton: View {
    let title: LocalizedStringKey
    var icon: String? = nil
    var color: Color = DS.cyan
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 15, weight: .bold)) }
                Text(title).font(DS.display(16))
            }
            .foregroundStyle(Color(hex: "#03141A"))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(LinearGradient(colors: [color, color == DS.cyan ? DS.green : color.opacity(0.8)],
                                       startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shimmer()
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: color.opacity(0.45), radius: 14, y: 4)
        }
        .buttonStyle(PressScaleStyle())
    }
}

/// Buttons shrink slightly while pressed.
struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// A soft light band that sweeps across the view every few seconds.
struct Shimmer: ViewModifier {
    @State private var x: CGFloat = -1
    func body(content: Content) -> some View {
        content.overlay {
            GeometryReader { g in
                LinearGradient(colors: [.clear, .white.opacity(0.45), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: g.size.width * 0.35)
                    .rotationEffect(.degrees(18))
                    .offset(x: x * g.size.width * 1.4)
            }
            .allowsHitTesting(false)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).delay(0.6).repeatForever(autoreverses: false)) { x = 1 }
        }
    }
}

extension View {
    func shimmer() -> some View { modifier(Shimmer()) }
}

struct DSNextCircleButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.right")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(hex: "#03141A"))
                .frame(width: 52, height: 52)
                .background(DS.cyan, in: Circle())
                .shadow(color: DS.cyan.opacity(0.6), radius: 12)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel("Next")
    }
}

struct DSPageDots: View {
    let count: Int
    let index: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == index ? DS.cyan : Color.white.opacity(0.25))
                    .frame(width: i == index ? 18 : 6, height: 6)
            }
        }
        .animation(.spring(response: 0.35), value: index)
    }
}

// MARK: - Surfaces

extension View {
    func dsCard(radius: CGFloat = 16, padding: CGFloat = 14) -> some View {
        self.padding(padding)
            .background(DS.card.opacity(0.88), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(DS.stroke, lineWidth: 1))
    }

    /// Glassy card for content that sits over a scenic backdrop.
    func dsGlass(radius: CGFloat = 18, padding: CGFloat = 14) -> some View {
        self.padding(padding)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(DS.bg.opacity(0.55))
            }
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(LinearGradient(colors: [DS.cyan.opacity(0.35), Color.white.opacity(0.06)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
    }
}

/// Feature row used by onboarding cards and the paywall ("✓ Drives recorded").
struct DSCheckRow: View {
    let text: String
    var color: Color = DS.cyan
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(color)
            Text(text).font(.system(size: 14, weight: .medium)).foregroundStyle(.white.opacity(0.9))
            Spacer(minLength: 0)
        }
    }
}

/// Icon over a label, used in the onboarding feature trios ("Auto Detects / AI Classifies / Tracks Securely").
struct DSFeatureIcon: View {
    let icon: String
    let label: String
    var highlighted = false
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(highlighted ? DS.cyan : .white.opacity(0.85))
                .frame(width: 44, height: 44)
                .background(Circle().fill(DS.card.opacity(0.8)))
                .overlay(Circle().strokeBorder(DS.cyan.opacity(highlighted ? 0.6 : 0.2), lineWidth: 1))
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(highlighted ? DS.cyan : .white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
