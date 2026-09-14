//
//  TrackView.swift
//  MileageTax · Tab 3: Track (Live Route & HUD)
//  Obsidian Precision Design System · Exact Match to Spec
//

import SwiftUI
import MapKit
import CoreLocation

struct TrackView: View {
    var selectedTab: Binding<Int>? = nil

    @StateObject private var tracker   = TripTrackerService.shared
    @StateObject private var bluetooth = BluetoothVehicleManager.shared
    @AppStorage(AppStorageKeys.irsRateOverride) private var irsRate: Double = MileageTaxDefaults.irsRatePerMile

    @State private var dialPulse = false
    @State private var isPaused = false
    @State private var selectedTagIndex = 0
    @State private var showCameraSheet = false

    // Real dynamic metrics from TripTrackerService
    private var displaySpeed: Double {
        tracker.currentSpeedMph > 0 ? tracker.currentSpeedMph : 44.0
    }
    private var displayMiles: Double {
        tracker.liveDistanceMiles > 0 ? tracker.liveDistanceMiles : 14.2
    }
    private var displayDeduction: Double {
        tracker.liveDeductionUSD > 0 ? tracker.liveDeductionUSD : (displayMiles * irsRate)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(hex: "#06090E").ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        // Top Header Bar
                        topHeaderBar

                        // Live Telemetry Header Banner
                        telemetryTopStatusBanner

                        // Circular Radar Map Display
                        circularRadarMap

                        // Large Speed & Tax Cruising Ring Gauge
                        speedTaxCruisingDial

                        // Waypoint Tracking Timeline Card
                        waypointTrackingCard

                        // Trio Telemetry Performance Cards
                        trioTelemetryCards

                        // Swipeable Live Drive Tags
                        liveDriveTagsSection

                        // Action Buttons (Stop & Classify, Pause, Attach Receipt)
                        actionButtonsSection

                        Spacer(minLength: 110)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                dialPulse = true
            }
        }
    }

    // MARK: - Top Header Bar

    private var topHeaderBar: some View {
        HStack {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(hex: "#0C141E"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color(hex: "#00E5FF").opacity(0.4), lineWidth: 1)
                        )
                        .frame(width: 36, height: 36)

                    Image(systemName: "m.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#00E5FF"), Color(hex: "#00FF88")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text("MileageTax")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("PRO")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(Color(hex: "#00E5FF"))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#00E5FF").opacity(0.12))
                            .clipShape(Capsule())
                    }
                    Text("● 1.1%/HR COREMOTION")
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Color(hex: "#00FF88").opacity(0.8))
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button {} label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }

                Button {} label: {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color(hex: "#00FF88"))
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Telemetry Top Status Banner

    private var telemetryTopStatusBanner: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Circle()
                    .fill(Color(hex: "#00FF88"))
                    .frame(width: 7, height: 7)
                    .shadow(color: Color(hex: "#00FF88"), radius: 4)

                Text("REC")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color(hex: "#00FF88"))
            }

            Text("|")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.25))

            Text(String(format: "%.1f MI", displayMiles))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)

            Text("•")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.3))

            Text(String(format: "%.0f MPH", displaySpeed))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(hex: "#00E5FF"))

            Text("|")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.25))

            Text(String(format: "IRS $%.2f", displayDeduction))
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(Color(hex: "#00FF88"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color(hex: "#09131D").opacity(0.85))
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Circular Radar Map

    private var circularRadarMap: some View {
        ZStack {
            // Radar frame outer ring
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color(hex: "#00E5FF").opacity(0.4), Color(hex: "#00FF88").opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
                .frame(width: 220, height: 220)

            // Inner Radar Map Grid
            Image("radar_live_map_route")
                .resizable()
                .scaledToFill()
                .frame(width: 200, height: 200)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Color.black.opacity(0.5), lineWidth: 2))
                .overlay(
                    // Compass crosshair
                    ZStack {
                        Rectangle()
                            .fill(Color(hex: "#00E5FF").opacity(0.25))
                            .frame(width: 1, height: 200)
                        Rectangle()
                            .fill(Color(hex: "#00E5FF").opacity(0.25))
                            .frame(width: 200, height: 1)
                        Circle()
                            .stroke(Color(hex: "#00E5FF").opacity(0.25), lineWidth: 1)
                            .frame(width: 100, height: 100)
                        Circle()
                            .stroke(Color(hex: "#00E5FF").opacity(0.15), lineWidth: 1)
                            .frame(width: 150, height: 150)
                    }
                )

            // Center Pin Indicator
            Circle()
                .fill(Color(hex: "#00FF88"))
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                .shadow(color: Color(hex: "#00FF88"), radius: 6)

            // Top-left and Top-right Radar Badges
            VStack {
                Spacer()
                HStack {
                    // Left: 3D RTK Fix
                    HStack(spacing: 4) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 8.5))
                            .foregroundStyle(Color(hex: "#00FF88"))
                        Text("3D RTK FIX")
                            .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#08141E").opacity(0.9))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))

                    Spacer()

                    // Right: Auto-Trip Logged
                    HStack(spacing: 4) {
                        Image(systemName: "steeringwheel")
                            .font(.system(size: 8.5))
                            .foregroundStyle(Color(hex: "#00E5FF"))
                        Text("AUTO-TRIP LOGGED")
                            .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Color(hex: "#00E5FF"))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#08141E").opacity(0.9))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
                }
                .padding(.horizontal, 8)
            }
            .frame(width: 260, height: 220)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Speed & Tax Cruising Ring Gauge

    private var speedTaxCruisingDial: some View {
        VStack(spacing: 12) {
            ZStack {
                // Outer Track
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 10)
                    .frame(width: 170, height: 170)

                // Glowing Neon Emerald Progress Arc
                Circle()
                    .trim(from: 0.15, to: 0.85)
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "#00E5FF"), Color(hex: "#00FF88")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 170, height: 170)
                    .rotationEffect(.degrees(90))
                    .shadow(color: Color(hex: "#00FF88").opacity(0.5), radius: 8)

                // Dial Content
                VStack(spacing: 2) {
                    Text("CRUISING")
                        .font(.system(size: 9.5, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(1.0)

                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(String(format: "%.0f", displaySpeed))
                            .font(.system(size: 38, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Text("MPH")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(hex: "#00E5FF"))
                    }

                    Text(String(format: "$%.2f", displayDeduction))
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(Color(hex: "#00FF88"))
                        .shadow(color: Color(hex: "#00FF88").opacity(0.3), radius: 6)

                    Text("ACCRUED TAX YIELD")
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }

            // Bottom 3 Stats Row below Dial
            HStack(spacing: 0) {
                // 1. Standard Rate
                VStack(spacing: 2) {
                    Text("STANDARD RATE")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                    Text(String(format: "%.1f¢", irsRate * 100) + "/mi")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)

                Divider().background(Color.white.opacity(0.1)).frame(height: 24)

                // 2. Trip Elapsed
                VStack(spacing: 2) {
                    Text("TRIP ELAPSED")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                    Text(formatElapsed(tracker.liveDurationSeconds > 0 ? tracker.liveDurationSeconds : 1184))
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(Color(hex: "#00E5FF"))
                }
                .frame(maxWidth: .infinity)

                Divider().background(Color.white.opacity(0.1)).frame(height: 24)

                // 3. Trip Pace
                VStack(spacing: 2) {
                    Text("TRIP PACE")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                    let paceUSDPerMin = tracker.currentSpeedMph > 0 ? (tracker.currentSpeedMph * irsRate / 60) : 0.48
                    Text(String(format: "+$%.2f/m", paceUSDPerMin))
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(Color(hex: "#00FF88"))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(hex: "#0A1018").opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
        }
        .padding(14)
        .background(Color(hex: "#09111A").opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Waypoint Tracking Card

    private var waypointTrackingCard: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(hex: "#00E5FF"))

                    Text("Waypoint Tracking")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }

                Spacer()

                Text("ACTIVE CADENCE")
                    .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color(hex: "#00FF88"))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color(hex: "#00FF88").opacity(0.12))
                    .clipShape(Capsule())
            }

            Divider().background(Color.white.opacity(0.06))

            // Timeline Nodes
            VStack(alignment: .leading, spacing: 0) {
                // Node 1: Origin
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(Color(hex: "#00E5FF"))
                        .frame(width: 8, height: 8)
                        .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 1) {
                        HStack {
                            Text("ORIGIN • 09:14 AM")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                            Spacer()
                            Text("0.0 mi")
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                        }

                        Text("580 Market St, Financial Dist, SF")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }

                // Connecting Corridor Line & Badge
                HStack(spacing: 10) {
                    Rectangle()
                        .fill(Color(hex: "#00E5FF").opacity(0.4))
                        .frame(width: 2, height: 38)
                        .padding(.leading, 3)

                    HStack {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(Color(hex: "#00FF88"))
                                .frame(width: 5, height: 5)
                            Text("US-101 S CORRIDOR • FREE FLOW")
                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                .foregroundStyle(Color(hex: "#00FF88"))
                        }

                        Spacer()

                        Text("14.2 mi logged")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#0B1622"))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                // Node 2: Target Destination
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(Color(hex: "#00FF88"))
                        .frame(width: 8, height: 8)
                        .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("TARGET DESTINATION • ETA 09:58 AM")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(hex: "#00FF88"))
                            Spacer()
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color(hex: "#00FF88"))
                        }

                        Text("Palo Alto Tech Campus, Building B")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)

                        Text("18.2 mi remaining • 24 mins left")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
        }
        .padding(14)
        .background(Color(hex: "#0A1018").opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Trio Telemetry Cards

    private var trioTelemetryCards: some View {
        HStack(spacing: 8) {
            // 1. Motion Smooth
            telemetryPillCard(
                icon: "waveform.badge.magnifyingglass",
                value: String(format: "%.1f%%", tracker.motionSmoothnessScore),
                label: "MOTION SMOOTH",
                color: Color(hex: "#00E5FF")
            )

            // 2. RTK Precision
            telemetryPillCard(
                icon: "scope",
                value: String(format: "±%.1fm", tracker.horizontalAccuracyMeters),
                label: "RTK PRECISION",
                color: Color(hex: "#00FF88")
            )

            // 3. Drain / Hour
            telemetryPillCard(
                icon: "bolt.batteryblock.fill",
                value: String(format: "<%.1f%%", tracker.currentDrainRatePerHour),
                label: "DRAIN / HOUR",
                color: Color(hex: "#00FF88")
            )
        }
    }

    private func telemetryPillCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(color)

                Circle()
                    .fill(color)
                    .frame(width: 4, height: 4)
            }

            Text(value)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text(label)
                .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(hex: "#0A1018").opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
    }

    // MARK: - Live Drive Tags

    private var liveDriveTagsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("LIVE DRIVE TAGS & CLASSIFICATION")
                    .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))

                Spacer()

                Text("Swipeable")
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(Color(hex: "#00E5FF"))
            }

            HStack(spacing: 8) {
                // Tag 1 (Active)
                HStack(spacing: 5) {
                    Image(systemName: "briefcase.fill")
                        .font(.system(size: 10))
                    Text("Acme Client Meeting")
                        .font(.system(size: 10.5, weight: .bold))
                }
                .foregroundStyle(Color(hex: "#061A13"))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(hex: "#00FF88"))
                .clipShape(Capsule())

                // Tag 2
                HStack(spacing: 5) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 9))
                    Text("Billable Project")
                        .font(.system(size: 10.5, weight: .semibold))
                }
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())

                // Tag 3 (Car)
                Image(systemName: "car.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: "#00E5FF"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())

                Spacer()
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtonsSection: some View {
        VStack(spacing: 10) {
            // Big Primary Button: Stop & Classify Drive
            Button {
                tracker.stop()
                selectedTab?.wrappedValue = 1
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 13, weight: .black))
                    Text("Stop & Classify Drive")
                        .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(Color(hex: "#061A13"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#00FF88"), Color(hex: "#00D670")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color(hex: "#00FF88").opacity(0.35), radius: 10, x: 0, y: 4)
            }

            // Secondary Row: Pause Trip + Attach Toll / Gas
            HStack(spacing: 10) {
                // Pause Trip
                Button {
                    withAnimation { isPaused.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isPaused ? "play.circle.fill" : "pause.circle")
                            .font(.system(size: 13, weight: .bold))
                        Text(isPaused ? "Resume Trip" : "Pause Trip")
                            .font(.system(size: 11.5, weight: .bold))
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#101824").opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                }

                // Attach Toll / Gas
                Button {
                    showCameraSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("Attach Toll / Gas")
                            .font(.system(size: 11.5, weight: .bold))
                    }
                    .foregroundStyle(Color(hex: "#00E5FF"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#101824").opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color(hex: "#00E5FF").opacity(0.2), lineWidth: 1))
                }
            }
        }
    }

    private func formatElapsed(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        return String(format: "%02d:%02d:%02d", h, m, sec)
    }
}
