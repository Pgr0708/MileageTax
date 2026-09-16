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

// MARK: - Standard Home Screen Widget (Prevents Xcode launch error Code=8)

struct QuickWidgetEntry: TimelineEntry {
    let date: Date
    let ytdDeduction: Double
    let ytdMiles: Double
    let isTracking: Bool
}

struct QuickWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickWidgetEntry {
        QuickWidgetEntry(date: Date(), ytdDeduction: 4892.45, ytdMiles: 7362.1, isTracking: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickWidgetEntry) -> Void) {
        completion(QuickWidgetEntry(date: Date(), ytdDeduction: 4892.45, ytdMiles: 7362.1, isTracking: false))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickWidgetEntry>) -> Void) {
        let entry = QuickWidgetEntry(date: Date(), ytdDeduction: 4892.45, ytdMiles: 7362.1, isTracking: false)
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600)))
        completion(timeline)
    }
}

struct MileageTaxQuickWidgetView: View {
    var entry: QuickWidgetProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.06, blue: 0.09)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "safari.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(red: 0.0, green: 0.9, blue: 1.0))
                    Text("MileageTax")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Circle()
                        .fill(Color(red: 0.0, green: 1.0, blue: 0.5))
                        .frame(width: 6, height: 6)
                }

                Spacer()

                Text("YTD WRITE-OFF")
                    .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))

                Text(String(format: "$%.2f", entry.ytdDeduction))
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.0, green: 1.0, blue: 0.5))

                HStack(spacing: 4) {
                    Text(String(format: "%.1f mi", entry.ytdMiles))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("• 67¢/mi")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(12)
        }
        .containerBackground(Color(red: 0.04, green: 0.06, blue: 0.09), for: .widget)
    }
}

struct MileageTaxQuickWidget: Widget {
    let kind: String = "MileageTaxQuickWidget"

    init() {}

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickWidgetProvider()) { entry in
            MileageTaxQuickWidgetView(entry: entry)
        }
        .configurationDisplayName("MileageTax Write-Off")
        .description("Track your YTD tax deduction and mileage at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
