//
//  MileageTaxLiveActivityBundle.swift
//  MileageTaxLiveActivity
//

import WidgetKit
import SwiftUI

@main
struct MileageTaxLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        MileageTaxLiveActivity()
        MileageTaxQuickWidget()
    }
}

// MARK: - Shared data (the app writes these into the App Group defaults)

private let widgetDefaults = UserDefaults(suiteName: "group.com.inovexa.mileagetax") ?? .standard

// MARK: - Timeline Entry

struct QuickWidgetEntry: TimelineEntry {
    let date: Date
    var ytdDeduction: Double
    var ytdMiles: Double
    var tripCount: Int
    var ratePerMile: Double
    var currency: String
    var unit: String
    var isTracking: Bool
    var liveDeduction: Double
    var liveMiles: Double
    var liveSpeed: Double

    static func current() -> QuickWidgetEntry {
        let d = widgetDefaults
        let rate = d.double(forKey: "widget.ratePerMile")
        return QuickWidgetEntry(
            date: Date(),
            ytdDeduction: d.double(forKey: "widget.ytdDeduction"),
            ytdMiles: d.double(forKey: "widget.ytdMiles"),
            tripCount: d.integer(forKey: "widget.tripCount"),
            ratePerMile: rate > 0 ? rate : 0.67,
            currency: d.string(forKey: "widget.currency") ?? "$",
            unit: d.string(forKey: "widget.unit") ?? "mi",
            isTracking: d.bool(forKey: "widget.isTracking"),
            liveDeduction: d.double(forKey: "widget.liveDeduction"),
            liveMiles: d.double(forKey: "widget.liveMiles"),
            liveSpeed: d.double(forKey: "widget.liveSpeed"))
    }

    static let sample = QuickWidgetEntry(date: Date(), ytdDeduction: 4386.20, ytdMiles: 1248.4, tripCount: 142,
                                         ratePerMile: 0.67, currency: "$", unit: "mi", isTracking: false,
                                         liveDeduction: 0, liveMiles: 0, liveSpeed: 0)

    static let liveSample = QuickWidgetEntry(date: Date(), ytdDeduction: 4386.20, ytdMiles: 1248.4, tripCount: 142,
                                             ratePerMile: 0.67, currency: "$", unit: "mi", isTracking: true,
                                             liveDeduction: 7.12, liveMiles: 12.4, liveSpeed: 48)
}

// MARK: - Provider

struct QuickWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickWidgetEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (QuickWidgetEntry) -> Void) {
        // Widget gallery shows sample numbers instead of an empty $0.00.
        completion(context.isPreview ? .sample : .current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickWidgetEntry>) -> Void) {
        let entry = QuickWidgetEntry.current()
        // Refresh every 15 min normally, or every 30s when tracking
        let refresh: TimeInterval = entry.isTracking ? 30 : 900
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(refresh))))
    }
}

// MARK: - Style

private enum WStyle {
    static let cyan  = Color(red: 0.10, green: 0.85, blue: 0.96)
    static let green = Color(red: 0.13, green: 0.89, blue: 0.60)
    static let red   = Color(red: 0.94, green: 0.27, blue: 0.23)
    static let ink   = Color(red: 0.02, green: 0.035, blue: 0.05)
    static let money = LinearGradient(colors: [cyan, green], startPoint: .leading, endPoint: .trailing)

    static func display(_ size: CGFloat) -> Font { .custom("SpaceGrotesk-Bold", size: size) }
    static func tech(_ size: CGFloat) -> Font { .custom("ChakraPetch-Bold", size: size) }
}

private extension QuickWidgetEntry {
    var amount: Double { isTracking ? liveDeduction : ytdDeduction }
    var miles: Double { isTracking ? liveMiles : ytdMiles }

    func money(_ v: Double) -> String {
        currency + v.formatted(.number.precision(.fractionLength(2)).grouping(.automatic))
    }
    /// "$4.4K" style for tight spaces.
    func compactMoney(_ v: Double) -> String {
        currency + v.formatted(.number.notation(.compactName).precision(.fractionLength(0...1)))
    }
    var milesText: String { miles.formatted(.number.precision(.fractionLength(miles < 100 ? 1 : 0))) + " " + unit }
    var rateText: String {
        currency == "$" ? "\(Int((ratePerMile * 100).rounded()))¢/\(unit)" : "\(currency)\(ratePerMile)/\(unit)"
    }
}

// MARK: - Building blocks

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

private struct StatusPill: View {
    let entry: QuickWidgetEntry
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(entry.isTracking ? WStyle.red : WStyle.green)
                .frame(width: 6, height: 6)
                .shadow(color: entry.isTracking ? WStyle.red : WStyle.green, radius: 3)
            Text(entry.isTracking ? "LIVE" : "SYNCED")
                .font(WStyle.tech(9)).tracking(1)
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Capsule().fill(.black.opacity(0.45)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 0.5))
    }
}

private struct StatChip: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 9, weight: .bold)).foregroundStyle(WStyle.cyan)
            Text(text).font(WStyle.tech(10)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.black.opacity(0.42)))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
    }
}

/// Photo background: the image plus gradients that keep the text on the left/bottom legible.
private struct PhotoBackground: View {
    let image: String
    var fromLeading = true
    var body: some View {
        ZStack {
            WStyle.ink
            Image(image).resizable().scaledToFill()
            LinearGradient(stops: [.init(color: WStyle.ink.opacity(0.92), location: 0),
                                   .init(color: WStyle.ink.opacity(0.55), location: 0.5),
                                   .init(color: .clear, location: 0.85)],
                           startPoint: fromLeading ? .leading : .bottom, endPoint: fromLeading ? .trailing : .top)
            LinearGradient(colors: [WStyle.ink.opacity(0.55), .clear], startPoint: .top, endPoint: .center)
        }
    }
}

// MARK: - Small Widget View

struct SmallWidgetView: View {
    var entry: QuickWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                AppLogo(size: 24)
                Spacer()
                StatusPill(entry: entry)
            }
            Spacer(minLength: 0)
            Text(entry.isTracking ? "THIS DRIVE" : "YTD WRITE-OFF")
                .font(WStyle.tech(9)).tracking(1.2)
                .foregroundStyle(.white.opacity(0.7))
            Text(entry.money(entry.amount))
                .font(WStyle.display(26))
                .foregroundStyle(WStyle.money)
                .lineLimit(1).minimumScaleFactor(0.55)
                .contentTransition(.numericText(value: entry.amount))
                .widgetAccentable()
            Text(entry.isTracking
                 ? "\(entry.milesText) · \(Int(entry.liveSpeed)) mph"
                 : "\(entry.milesText) · \(entry.tripCount) drives")
                .font(WStyle.tech(10))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .containerBackground(for: .widget) {
            PhotoBackground(image: entry.isTracking ? "widget_bg_live" : "widget_bg_small", fromLeading: false)
        }
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    var entry: QuickWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                AppLogo(size: 26)
                (Text("Mileage").foregroundStyle(.white) + Text("Tax").foregroundStyle(WStyle.money))
                    .font(WStyle.display(15))
                Spacer()
                StatusPill(entry: entry)
            }
            Spacer(minLength: 4)
            Text(entry.isTracking ? "THIS DRIVE · WRITE-OFF" : "YTD VERIFIED WRITE-OFF")
                .font(WStyle.tech(9.5)).tracking(1.4)
                .foregroundStyle(.white.opacity(0.7))
            Text(entry.money(entry.amount))
                .font(WStyle.display(36))
                .foregroundStyle(WStyle.money)
                .shadow(color: WStyle.cyan.opacity(0.35), radius: 8)
                .lineLimit(1).minimumScaleFactor(0.6)
                .contentTransition(.numericText(value: entry.amount))
                .widgetAccentable()
            Spacer(minLength: 4)
            HStack(spacing: 6) {
                StatChip(icon: "road.lanes", text: entry.milesText)
                if entry.isTracking {
                    StatChip(icon: "speedometer", text: "\(Int(entry.liveSpeed)) mph")
                } else {
                    StatChip(icon: "car.fill", text: "\(entry.tripCount) drives")
                }
                StatChip(icon: "gauge.with.dots.needle.67percent", text: entry.rateText)
                Spacer(minLength: 0)
            }
        }
        .containerBackground(for: .widget) {
            PhotoBackground(image: entry.isTracking ? "widget_bg_live" : "widget_bg_medium")
        }
    }
}

// MARK: - Lock Screen Views

struct CircularWidgetView: View {
    var entry: QuickWidgetEntry
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                AppLogo(size: 16)
                Text(entry.compactMoney(entry.amount))
                    .font(WStyle.display(14))
                    .lineLimit(1).minimumScaleFactor(0.5)
                    .widgetAccentable()
            }
            .padding(4)
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

struct RectangularWidgetView: View {
    var entry: QuickWidgetEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                AppLogo(size: 12)
                Text(entry.isTracking ? "LIVE DRIVE" : "YTD WRITE-OFF")
            }
            .font(WStyle.tech(10))
            .widgetAccentable()
            Text(entry.money(entry.amount))
                .font(WStyle.display(20))
                .lineLimit(1).minimumScaleFactor(0.6)
            Text("\(entry.milesText) · \(entry.rateText)")
                .font(WStyle.tech(10))
                .opacity(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color.clear }
    }
}

struct InlineWidgetView: View {
    var entry: QuickWidgetEntry
    var body: some View {
        // Inline slots only render text + SF Symbols, so the brand is spelled out instead.
        Text("MileageTax \(entry.money(entry.amount)) · \(entry.milesText)")
            .containerBackground(for: .widget) { Color.clear }
    }
}

// MARK: - Combined View

struct MileageTaxQuickWidgetView: View {
    var entry: QuickWidgetProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:           SmallWidgetView(entry: entry)
        case .accessoryCircular:     CircularWidgetView(entry: entry)
        case .accessoryRectangular:  RectangularWidgetView(entry: entry)
        case .accessoryInline:       InlineWidgetView(entry: entry)
        default:                     MediumWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget Definition

struct MileageTaxQuickWidget: Widget {
    let kind: String = "MileageTaxQuickWidget"

    init() {}

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickWidgetProvider()) { entry in
            MileageTaxQuickWidgetView(entry: entry)
        }
        .configurationDisplayName("MileageTax Write-Off")
        .description("YTD tax deduction, mileage, and live trip tracking at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium,
                            .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

#Preview("Medium", as: .systemMedium) { MileageTaxQuickWidget() } timeline: {
    QuickWidgetEntry.sample
    QuickWidgetEntry.liveSample
}

#Preview("Small", as: .systemSmall) { MileageTaxQuickWidget() } timeline: { QuickWidgetEntry.sample }
