// AppTheme.swift — MileageTax "Obsidian Precision" Design System
import SwiftUI

// MARK: - Palette
extension Color {
    static let obsidian        = Color(hex: "#07090E")
    static let obsidianDeep    = Color(hex: "#020407")
    static let glassBorder     = Color.white.opacity(0.08)
    static let glassHighlight  = Color.white.opacity(0.04)
    static let neonEmerald     = Color(hex: "#00FF88")
    static let emeraldMid      = Color(hex: "#00C866")
    static let emeraldDim      = Color(hex: "#00C866").opacity(0.18)
    static let electricCyan    = Color(hex: "#00E5FF")
    static let amberGlow       = Color(hex: "#FFB020")
    static let crimsonPulse    = Color(hex: "#FF3B5C")
    static let deepPurple      = Color(hex: "#7B4FFF")
    static let textPrimary     = Color.white
    static let textSecondary   = Color.white.opacity(0.60)
    static let textTertiary    = Color.white.opacity(0.35)
    static let textOnAccent    = Color(hex: "#07090E")
}

// MARK: - Gradients
enum AppGradient {
    static let radarBg = LinearGradient(
        colors: [Color(hex: "#07090E"), Color(hex: "#0A1A15")],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    static let emeraldPulse = LinearGradient(
        colors: [Color.neonEmerald, Color.emeraldMid],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    static let cyanEmerald = LinearGradient(
        colors: [Color.electricCyan, Color.neonEmerald],
        startPoint: .leading, endPoint: .trailing)
    static let dangerGradient = LinearGradient(
        colors: [Color.crimsonPulse, Color(hex: "#FF6B35")],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    static let purpleGradient = LinearGradient(
        colors: [Color.deepPurple, Color(hex: "#B47AFF")],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    static let goldGradient = LinearGradient(
        colors: [Color(hex: "#FFD700"), Color.amberGlow],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    static let glassCard = LinearGradient(
        colors: [Color.white.opacity(0.07), Color.white.opacity(0.02)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
}

// MARK: - Typography
extension Font {
    static let displayHero   = Font.system(size: 52, weight: .black,   design: .rounded)
    static let displayLarge  = Font.system(size: 36, weight: .bold,    design: .rounded)
    static let displayMedium = Font.system(size: 28, weight: .bold,    design: .rounded)
    static let headline      = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let subheadline   = Font.system(size: 15, weight: .medium,  design: .rounded)
    static let bodyText      = Font.system(size: 14, weight: .regular, design: .rounded)
    static let captionText   = Font.system(size: 12, weight: .medium,  design: .rounded)
    static let micro         = Font.system(size: 10, weight: .semibold, design: .rounded)
    static let monoLarge     = Font.system(size: 28, weight: .bold,    design: .monospaced)
}

// MARK: - Spacing
enum AppSpacing {
    static let xs: CGFloat  = 4
    static let sm: CGFloat  = 8
    static let md: CGFloat  = 16
    static let lg: CGFloat  = 24
    static let xl: CGFloat  = 32
    static let xxl: CGFloat = 48
}

// MARK: - Radii
enum AppRadius {
    static let sm:   CGFloat = 10
    static let md:   CGFloat = 16
    static let lg:   CGFloat = 24
    static let pill: CGFloat = 50
}

// MARK: - View Modifiers
extension View {
    func glassCard(radius: CGFloat = AppRadius.md, shadow: Bool = true) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(AppGradient.glassCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(Color.glassBorder, lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(shadow ? 0.4 : 0), radius: 16, x: 0, y: 8)
    }

    func emeraldGlow(radius: CGFloat = 12, opacity: CGFloat = 0.4) -> some View {
        self.shadow(color: Color.neonEmerald.opacity(opacity), radius: radius)
    }

    func cyanGlow(radius: CGFloat = 10, opacity: CGFloat = 0.45) -> some View {
        self.shadow(color: Color.electricCyan.opacity(opacity), radius: radius)
    }
}
