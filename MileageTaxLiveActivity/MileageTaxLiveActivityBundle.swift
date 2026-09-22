//
//  MileageTaxLiveActivityBundle.swift
//  MileageTaxLiveActivity
//

import WidgetKit
import SwiftUI
import CoreData

@main
struct MileageTaxLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        MileageTaxLiveActivity()
        MileageTaxQuickWidget()
    }
}

// MARK: - CoreData read helpers (widget process shares the same App Group store)

private func fetchWidgetData() -> (ytdDeduction: Double, ytdMiles: Double, isTracking: Bool, liveDeduction: Double, liveMiles: Double, liveSpeed: Double) {
    // Widgets share the same SQLite via App Group, but for simplicity read from UserDefaults
    // which the main app keeps updated via a shared App Group suite
    let defaults = UserDefaults(suiteName: "group.com.inovexa.mileagetax") ?? .standard
    let ytdDeduction  = defaults.double(forKey: "widget.ytdDeduction")
    let ytdMiles      = defaults.double(forKey: "widget.ytdMiles")
    let isTracking    = defaults.bool(forKey: "widget.isTracking")
    let liveDeduction = defaults.double(forKey: "widget.liveDeduction")
    let liveMiles     = defaults.double(forKey: "widget.liveMiles")
    let liveSpeed     = defaults.double(forKey: "widget.liveSpeed")
    return (ytdDeduction, ytdMiles, isTracking, liveDeduction, liveMiles, liveSpeed)
}

// MARK: - Timeline Entry

struct QuickWidgetEntry: TimelineEntry {
    let date: Date
    let ytdDeduction: Double
    let ytdMiles: Double
    let isTracking: Bool
    let liveDeduction: Double
    let liveMiles: Double
    let liveSpeed: Double
}

// MARK: - Provider

struct QuickWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickWidgetEntry {
        QuickWidgetEntry(date: Date(), ytdDeduction: 4892.45, ytdMiles: 7362.1, isTracking: false, liveDeduction: 0, liveMiles: 0, liveSpeed: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickWidgetEntry) -> Void) {
        let d = fetchWidgetData()
        completion(QuickWidgetEntry(date: Date(), ytdDeduction: d.ytdDeduction, ytdMiles: d.ytdMiles, isTracking: d.isTracking, liveDeduction: d.liveDeduction, liveMiles: d.liveMiles, liveSpeed: d.liveSpeed))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickWidgetEntry>) -> Void) {
        let d = fetchWidgetData()
        let entry = QuickWidgetEntry(date: Date(), ytdDeduction: d.ytdDeduction, ytdMiles: d.ytdMiles, isTracking: d.isTracking, liveDeduction: d.liveDeduction, liveMiles: d.liveMiles, liveSpeed: d.liveSpeed)
        // Refresh every 15 min normally, or every 30s when tracking
        let refreshInterval: TimeInterval = d.isTracking ? 30 : 900
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(refreshInterval)))
        completion(timeline)
    }
}

// MARK: - Small Widget View

struct SmallWidgetView: View {
    var entry: QuickWidgetEntry

    var body: some View {
        ZStack {
            // Dark background with subtle mesh gradient
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.07, blue: 0.12), Color(red: 0.02, green: 0.04, blue: 0.07)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            // Subtle neon glow orb
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 0.0, green: 1.0, blue: 0.53).opacity(0.18), .clear],
                        center: .center, startRadius: 0, endRadius: 70
                    )
                )
                .frame(width: 140, height: 140)
                .offset(x: -20, y: 40)

            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(spacing: 5) {
                    Image(systemName: "bolt.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(red: 0.0, green: 0.9, blue: 1.0))
                    Text("MileageTax")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    if entry.isTracking {
                        Circle()
                            .fill(Color(red: 0.0, green: 1.0, blue: 0.53))
                            .frame(width: 7, height: 7)
                    }
                }

                Spacer()

                if entry.isTracking {
                    // LIVE trip mode
                    Text("LIVE DRIVE")
                        .font(.system(size: 7.5, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Color(red: 0.0, green: 1.0, blue: 0.53).opacity(0.8))
                        .tracking(1)

                    Text(String(format: "+$%.2f", entry.liveDeduction))
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 0.0, green: 1.0, blue: 0.53))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(String(format: "%.1f mi · %.0f mph", entry.liveMiles, entry.liveSpeed))
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                } else {
                    // YTD mode
                    Text("YTD WRITE-OFF")
                        .font(.system(size: 7.5, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                        .tracking(1)

                    Text(String(format: "$%.2f", entry.ytdDeduction))
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 0.0, green: 1.0, blue: 0.53))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(String(format: "%.1f mi · 67¢/mi", entry.ytdMiles))
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .padding(14)
        }
        .containerBackground(Color(red: 0.04, green: 0.06, blue: 0.09), for: .widget)
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    var entry: QuickWidgetEntry

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.07, blue: 0.12), Color(red: 0.02, green: 0.04, blue: 0.08)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            // Glowing orb
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 0.0, green: 1.0, blue: 0.53).opacity(0.14), .clear],
                        center: .center, startRadius: 0, endRadius: 120
                    )
                )
                .frame(width: 240, height: 240)
                .offset(x: 80, y: 30)

            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(red: 0.0, green: 0.9, blue: 1.0))
                        Text("MileageTax")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    if entry.isTracking {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(red: 0.0, green: 1.0, blue: 0.53))
                                .frame(width: 6, height: 6)
                            Text("TRACKING")
                                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                                .foregroundStyle(Color(red: 0.0, green: 1.0, blue: 0.53))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(red: 0.0, green: 1.0, blue: 0.53).opacity(0.12))
                        .clipShape(Capsule())
                    }
                }

                // Main metrics row
                HStack(spacing: 10) {
                    // Left: Big number
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.isTracking ? "TRIP WRITE-OFF" : "YTD WRITE-OFF")
                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                            .foregroundStyle(entry.isTracking
                                ? Color(red: 0.0, green: 1.0, blue: 0.53).opacity(0.8)
                                : .white.opacity(0.45))
                            .tracking(0.5)

                        Text(String(format: "$%.2f", entry.isTracking ? entry.liveDeduction : entry.ytdDeduction))
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(Color(red: 0.0, green: 1.0, blue: 0.53))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Divider
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 1, height: 40)

                    // Right: Miles
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("MILES")
                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.45))
                            .tracking(0.5)

                        Text(String(format: "%.1f", entry.isTracking ? entry.liveMiles : entry.ytdMiles))
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        if entry.isTracking {
                            Text(String(format: "%.0f mph", entry.liveSpeed))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }

                // Footer bar
                if !entry.isTracking {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.4))
                        Text("YTD · 67¢/mi IRS rate")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                        Spacer()
                        Text("Tap to open →")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.25))
                    }
                }
            }
            .padding(14)
        }
        .containerBackground(Color(red: 0.04, green: 0.06, blue: 0.09), for: .widget)
    }
}

// MARK: - Combined View

struct MileageTaxQuickWidgetView: View {
    var entry: QuickWidgetProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        default:
            MediumWidgetView(entry: entry)
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
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
