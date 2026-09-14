//
//  MileageTaxLiveActivity.swift
//  MileageTaxLiveActivity
//
//  Dynamic Island & Lock Screen Live Activity for MileageTax
//  Real-time IRS deduction, trip miles, speedometer, and route tracking.
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Activity Attributes (Must match LiveActivityManager.swift)

public struct TripLiveActivityAttributes: ActivityAttributes {
    public typealias ContentState = TripLiveActivityContent

    public struct TripLiveActivityContent: Codable, Hashable {
        public var distanceMiles:  Double
        public var speedMph:       Double
        public var deductionUSD:   Double
        public var elapsedSeconds: Int
        public var startAddress:   String
        public var statusLabel:    String

        public init(distanceMiles: Double,
                    speedMph: Double,
                    deductionUSD: Double,
                    elapsedSeconds: Int,
                    startAddress: String,
                    statusLabel: String) {
            self.distanceMiles  = distanceMiles
            self.speedMph       = speedMph
            self.deductionUSD   = deductionUSD
            self.elapsedSeconds = elapsedSeconds
            self.startAddress   = startAddress
            self.statusLabel    = statusLabel
        }
    }

    public var tripID: String
    public var vehicleName: String

    public init(tripID: String, vehicleName: String) {
        self.tripID      = tripID
        self.vehicleName = vehicleName
    }
}

// MARK: - Live Activity Widget Definition

public struct MileageTaxLiveActivity: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: TripLiveActivityAttributes.self) { context in
            // MARK: Lock Screen & StandBy Banner
            LockScreenLiveActivityView(context: context)
                .activityBackgroundTint(Color(red: 0.04, green: 0.06, blue: 0.08))
                .activitySystemActionForegroundColor(Color(red: 0.0, green: 1.0, blue: 0.5))

        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: Expanded Region - Leading
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "car.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(red: 0.0, green: 1.0, blue: 0.5))
                            Text(context.attributes.vehicleName.isEmpty ? "My Vehicle" : context.attributes.vehicleName)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.8))
                                .lineLimit(1)
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(String(format: "%.0f", context.state.speedMph))
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                            Text("MPH")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .padding(.leading, 4)
                }

                // MARK: Expanded Region - Trailing
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("TAX WRITE-OFF")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(Color(red: 0.0, green: 1.0, blue: 0.5).opacity(0.9))
                            .tracking(0.5)

                        Text(String(format: "+$%.2f", context.state.deductionUSD))
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(Color(red: 0.0, green: 1.0, blue: 0.5))
                    }
                    .padding(.trailing, 4)
                }

                // MARK: Expanded Region - Center
                DynamicIslandExpandedRegion(.center) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(red: 0.0, green: 1.0, blue: 0.5))
                            .frame(width: 6, height: 6)

                        Text(context.state.statusLabel.uppercased())
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(Color(red: 0.0, green: 1.0, blue: 0.5))
                            .tracking(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(red: 0.0, green: 1.0, blue: 0.5).opacity(0.12))
                    .clipShape(Capsule())
                }

                // MARK: Expanded Region - Bottom
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        Divider()
                            .overlay(Color.white.opacity(0.1))

                        HStack(spacing: 0) {
                            // Distance
                            VStack(alignment: .leading, spacing: 1) {
                                Text("DISTANCE")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.4))
                                Text(String(format: "%.2f mi", context.state.distanceMiles))
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            // Elapsed Time
                            VStack(alignment: .center, spacing: 1) {
                                Text("TIME")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.4))
                                Text(formatTime(context.state.elapsedSeconds))
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)

                            // IRS Rate
                            VStack(alignment: .trailing, spacing: 1) {
                                Text("IRS RATE")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.4))
                                Text("$0.67/mi")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(red: 0.0, green: 1.0, blue: 0.5))
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }

                        if !context.state.startAddress.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color(red: 0.0, green: 1.0, blue: 0.5))
                                Text(context.state.startAddress)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.6))
                                    .lineLimit(1)
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.bottom, 4)
                }

            } compactLeading: {
                // MARK: Compact Leading (Left Pill)
                HStack(spacing: 4) {
                    Image(systemName: "steeringwheel")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Color(red: 0.0, green: 1.0, blue: 0.5))
                    Text(String(format: "%.1f", context.state.distanceMiles))
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.leading, 2)

            } compactTrailing: {
                // MARK: Compact Trailing (Right Pill)
                Text(String(format: "+$%.2f", context.state.deductionUSD))
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 0.0, green: 1.0, blue: 0.5))
                    .padding(.trailing, 2)

            } minimal: {
                // MARK: Minimal (Small Circle)
                Image(systemName: "steeringwheel")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Color(red: 0.0, green: 1.0, blue: 0.5))
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }
}

// MARK: - Lock Screen & StandBy View

private struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<TripLiveActivityAttributes>

    var body: some View {
        VStack(spacing: 12) {
            // Header: Vehicle Name + Status Pill + Speed
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(red: 0.0, green: 1.0, blue: 0.5))
                    Text(context.attributes.vehicleName.isEmpty ? "MileageTax Active Drive" : context.attributes.vehicleName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }

                Spacer()

                HStack(spacing: 5) {
                    Circle()
                        .fill(Color(red: 0.0, green: 1.0, blue: 0.5))
                        .frame(width: 6, height: 6)
                    Text(context.state.statusLabel.uppercased())
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(Color(red: 0.0, green: 1.0, blue: 0.5))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(red: 0.0, green: 1.0, blue: 0.5).opacity(0.15))
                .clipShape(Capsule())
            }

            // Big Metric Hero Cards
            HStack(spacing: 12) {
                // Left: Miles Logged
                VStack(alignment: .leading, spacing: 2) {
                    Text("DISTANCE")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(.white.opacity(0.4))
                        .tracking(0.5)

                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(String(format: "%.2f", context.state.distanceMiles))
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("mi")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Right: Tax Deduction
                VStack(alignment: .trailing, spacing: 2) {
                    Text("TAX SAVINGS")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(Color(red: 0.0, green: 1.0, blue: 0.5).opacity(0.8))
                        .tracking(0.5)

                    Text(String(format: "+$%.2f", context.state.deductionUSD))
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 0.0, green: 1.0, blue: 0.5))
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .background(Color(red: 0.0, green: 1.0, blue: 0.5).opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Footer: Speed, Duration, Start Address
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                    Text(String(format: "%.0f MPH", context.state.speedMph))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                    Text(formatTime(context.state.elapsedSeconds))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .padding(14)
        .background(Color(red: 0.05, green: 0.07, blue: 0.09))
    }

    private func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }
}
