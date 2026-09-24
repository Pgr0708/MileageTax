//
//  TrackView.swift
//  MileageTax · Tab 3: Track (Live Route & HUD)
//  Obsidian Precision Design System · Exact Match to Spec Mockup
//

import SwiftUI
import MapKit
import CoreLocation

struct TrackView: View {
    var selectedTab: Binding<Int>? = nil

    @StateObject private var tracker   = TripTrackerService.shared
    @StateObject private var bluetooth = BluetoothVehicleManager.shared
    @AppStorage(AppStorageKeys.irsRateOverride)  private var irsRate: Double        = MileageTaxDefaults.irsRatePerMile
    @AppStorage(AppStorageKeys.currencySymbol)    private var currencySymbol: String  = MileageTaxDefaults.defaultCurrencySymbol
    @AppStorage(AppStorageKeys.distanceUnit)      private var distanceUnit: String    = MileageTaxDefaults.defaultDistanceUnit

    @State private var dialPulse = false
    @State private var isPaused = false
    @State private var showCameraSheet = false
    @State private var liveClassification: String = "business"
    @State private var showManualStartConfirm = false

    // Real dynamic metrics from TripTrackerService
    private var isTracking: Bool {
        tracker.state == .activeTracking || tracker.state == .idleBuffer
    }
    private var displaySpeed: Double { tracker.currentSpeedMph }
    private var displayMiles: Double { tracker.liveDistanceMiles }
    private var displayDeduction: Double { tracker.liveDeductionUSD }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background Scene (Alpine coastal sunset with winding neon highway)
                scenicBackground

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Live Telemetry Banner (REC · 0.0 MI · 0 MPH · $0.00)
                        telemetryTopStatusBanner

                        // Highway Vista Badges (Floating over road scene)
                        highwayVistaBadges

                        Spacer()
                        
                        // Cruising Speed & Tax Yield Circular HUD Dial
                        speedTaxCruisingDial
//                            .padding(.top, 16)

                        // Live Route Map Card
                        liveRouteMapCard

                        // 3-Column Horizontal Metrics Glass Bar
                        threeColumnMetricsBar

                        // Waypoint Tracking Master Card (Includes Timeline, Telemetry Trio, and Live Tags)
                        waypointTrackingCard

                        // Primary Action CTA: Stop & Classify Drive
                        primaryActionCTA

                        Spacer(minLength: 120)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, Device.topSafeArea + 58) // safe area + header height
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                dialPulse = true
            }
        }
    }

    // MARK: - Scenic Background

    private var scenicBackground: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Color(hex: "#06090E").ignoresSafeArea()

                // High-resolution scenic coastal winding highway at sunset with green neon road trails
                Image("track_bg_scenic")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height * 0.72, alignment: .top)
                    .clipped()
                    .ignoresSafeArea(edges: .top)
                    .overlay(
                        LinearGradient(
                            stops: [
                                .init(color: Color.clear, location: 0.0),
                                .init(color: Color.clear, location: 0.22),
                                .init(color: Color(hex: "#06090E").opacity(0.18), location: 0.40),
                                .init(color: Color(hex: "#06090E").opacity(0.70), location: 0.65),
                                .init(color: Color(hex: "#06090E"), location: 0.90)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // Atmospheric cyan/emerald ambient aura
                RadialGradient(
                    colors: [Color(hex: "#00E5FF").opacity(0.12), Color.clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 300
                )
                .ignoresSafeArea()
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Live Telemetry Header Banner

    private var telemetryTopStatusBanner: some View {
        HStack(spacing: 9) {
            // REC / STANDBY indicator
            HStack(spacing: 5) {
                Circle()
                    .fill(isTracking ? Color(hex: "#00FF88") : Color.gray.opacity(0.5))
                    .frame(width: 7, height: 7)
                    .shadow(color: isTracking ? Color(hex: "#00FF88") : Color.clear, radius: 4)

                Text(isTracking ? "REC" : "STANDBY")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(isTracking ? Color(hex: "#00FF88") : Color.gray)
            }

            Text("|")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.25))

            Text(String(format: "%.1f MI", displayMiles))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)

            Text("|")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.25))

            Text(String(format: "%.0f %@", MileageUnits.speedValue(displaySpeed), MileageUnits.speedUnitLabel))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(hex: "#00E5FF"))

            Text("|")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.25))

            HStack(spacing: 3) {
                Text("IRS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
                Text(String(format: "$%.2f", displayDeduction))
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color(hex: "#00FF88"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            ZStack {
                Color(hex: "#06101B").opacity(0.75)
                Rectangle().fill(.ultraThinMaterial.opacity(0.45))
            }
        )
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Color(hex: "#00E5FF").opacity(0.35), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.35), radius: 8, y: 4)
    }

    // MARK: - Highway Vista Badges

    private var highwayVistaBadges: some View {
        HStack {
            // Left Pill: GPS accuracy
            HStack(spacing: 5) {
                Image(systemName: "location.viewfinder")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isTracking ? Color(hex: "#00E5FF") : Color.gray)
                Text(isTracking ? String(format: "GPS ±%.0fm", tracker.horizontalAccuracyMeters) : "GPS: IDLE")
                    .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                    .foregroundStyle(isTracking ? .white : .white.opacity(0.4))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                ZStack {
                    Color(hex: "#06121C").opacity(0.75)
                    Rectangle().fill(.ultraThinMaterial.opacity(0.4))
                }
            )
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(isTracking ? Color(hex: "#00E5FF").opacity(0.35) : Color.white.opacity(0.1), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.3), radius: 6)

            Spacer()

            // Right Pill: Auto-detect status
            HStack(spacing: 5) {
                Image(systemName: isTracking ? "record.circle" : "antenna.radiowaves.left.and.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isTracking ? Color(hex: "#00FF88") : Color(hex: "#00E5FF"))
                Text(isTracking ? "TRIP ACTIVE" : "AUTO-SCANNING")
                    .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white)
                Circle()
                    .fill(isTracking ? Color(hex: "#00FF88") : Color(hex: "#00E5FF"))
                    .frame(width: 5, height: 5)
                    .shadow(color: isTracking ? Color(hex: "#00FF88") : Color(hex: "#00E5FF"), radius: 3)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                ZStack {
                    Color(hex: "#06121C").opacity(0.75)
                    Rectangle().fill(.ultraThinMaterial.opacity(0.4))
                }
            )
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(isTracking ? Color(hex: "#00FF88").opacity(0.35) : Color(hex: "#00E5FF").opacity(0.25), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.3), radius: 6)
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }

    // MARK: - Speed & Tax Cruising Ring Gauge

    private var speedTaxCruisingDial: some View {
        ZStack {
            // Outer atmospheric neon glow bloom
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#00E5FF").opacity(0.22), Color(hex: "#00FF88").opacity(0.08), Color.clear],
                        center: .center,
                        startRadius: 40,
                        endRadius: 135
                    )
                )
                .frame(width: 260, height: 260)

            // Outer gauge dial radial tick ring
            ZStack {
                ForEach(0..<29) { i in
                    Rectangle()
                        .fill(Color.white.opacity(i % 4 == 0 ? 0.45 : 0.18))
                        .frame(width: 1.5, height: i % 4 == 0 ? 7 : 4)
                        .offset(y: -110)
                        .rotationEffect(.degrees(Double(i) * 6.5 - 91))
                }
            }
            .frame(width: 226, height: 226)

            // Neon glowing gauge ring with smooth gradient
            Circle()
                .trim(from: 0.12, to: 0.88)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "#00E5FF"),
                            Color(hex: "#00FFCC"),
                            Color(hex: "#00FF88"),
                            Color(hex: "#00E5FF")
                        ]),
                        center: .center,
                        startAngle: .degrees(90),
                        endAngle: .degrees(450)
                    ),
                    style: StrokeStyle(lineWidth: 6.5, lineCap: .round)
                )
                .frame(width: 210, height: 210)
                .rotationEffect(.degrees(90))
                .shadow(color: Color(hex: "#00E5FF").opacity(0.6), radius: 10)
                .shadow(color: Color(hex: "#00FF88").opacity(0.5), radius: 6)

            // Inner dark frosted disc
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#081320").opacity(0.9), Color(hex: "#040910").opacity(0.96)],
                        center: .center,
                        startRadius: 20,
                        endRadius: 100
                    )
                )
                .frame(width: 194, height: 194)
                .overlay(
                    Circle().strokeBorder(
                        LinearGradient(
                            colors: [Color(hex: "#00E5FF").opacity(0.45), Color.white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                )
                .shadow(color: Color.black.opacity(0.5), radius: 12)

            // Dial Center Typography
            VStack(spacing: 3) {
                Text(isTracking ? "CRUISING" : "PARKED")
                    .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.65))
                    .tracking(1.8)
                    .padding(.top, 4)

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(isTracking ? String(format: "%.0f", MileageUnits.speedValue(displaySpeed)) : "0")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(isTracking ? .white : .white.opacity(0.3))

                    Text(MileageUnits.speedUnitLabel)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: "#00E5FF"))
                }

                // Divider line
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.clear, Color(hex: "#00E5FF").opacity(0.7), Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 78, height: 1.5)
                    .padding(.vertical, 1)

                if isTracking {
                    Text(String(format: "$%.2f", displayDeduction))
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(Color(hex: "#00FF88"))
                        .shadow(color: Color(hex: "#00FF88").opacity(0.5), radius: 8)

                    Text("ACCRUED TAX YIELD")
                        .font(.system(size: 7.5, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                        .tracking(0.8)
                } else {
                    Text("$0.00")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.25))

                    Text("START A TRIP TO TRACK")
                        .font(.system(size: 7.5, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                        .tracking(0.8)
                }
            }
        }
        .frame(height: 240)
        .padding(.vertical, 2)
    }

    // MARK: - 3-Column Metrics Glass Bar

    private var threeColumnMetricsBar: some View {
        HStack(spacing: 0) {
            // 1. Standard Rate
            VStack(spacing: 3) {
                HStack(spacing: 4) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(hex: "#00FF88"))
                    Text("STANDARD RATE")
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Text(String(format: "%.3f", irsRate) + currencySymbol + "/" + distanceUnit)
                    .font(.system(size: 13.5, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)

            Divider().background(Color.white.opacity(0.12)).frame(height: 26)

            // 2. Trip Elapsed
            VStack(spacing: 3) {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(hex: "#00E5FF"))
                    Text("TRIP ELAPSED")
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Text(formatElapsed(tracker.liveDurationSeconds))
                    .font(.system(size: 13.5, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(hex: "#00E5FF"))
            }
            .frame(maxWidth: .infinity)

            Divider().background(Color.white.opacity(0.12)).frame(height: 26)

            // 3. Trip Pace
            VStack(spacing: 3) {
                HStack(spacing: 4) {
                    Image(systemName: "circle.grid.cross.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(hex: "#00FF88"))
                    Text("TRIP PACE")
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
                let paceUSDPerMin = tracker.currentSpeedMph > 0 ? (tracker.currentSpeedMph * irsRate / 60) : 0.0
                Text(isTracking && paceUSDPerMin > 0 ? String(format: "+%@%.2f/m", currencySymbol, paceUSDPerMin) : "—")
                    .font(.system(size: 13.5, weight: .black, design: .monospaced))
                    .foregroundStyle(isTracking ? Color(hex: "#00FF88") : .white.opacity(0.3))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background(
            ZStack {
                Color(hex: "#08101A").opacity(0.85)
                Rectangle().fill(.ultraThinMaterial.opacity(0.45))
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color(hex: "#00E5FF").opacity(0.4), Color(hex: "#00FF88").opacity(0.2), Color.white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.4), radius: 10, y: 5)
    }

    // MARK: - Waypoint Tracking Master Card

    private var waypointTrackingCard: some View {
        VStack(spacing: 14) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color(hex: "#00E5FF"))

                    Text(isTracking ? "Live Waypoints" : "Trip Status")
                        .font(.system(size: 15.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(isTracking ? Color(hex: "#00FF88") : Color.gray)
                        .frame(width: 5, height: 5)
                        .shadow(color: isTracking ? Color(hex: "#00FF88") : Color.clear, radius: 3)
                    Text(isTracking ? "ACTIVE CADENCE" : "STANDBY")
                        .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                        .foregroundStyle(isTracking ? Color(hex: "#00FF88") : Color.gray)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: "#072018").opacity(0.9))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(isTracking ? Color(hex: "#00FF88").opacity(0.35) : Color.gray.opacity(0.2), lineWidth: 1))
            }

            Divider().background(Color.white.opacity(0.08))

            // Timeline Nodes — 100% real data
            VStack(alignment: .leading, spacing: 0) {
                // Node 1: Origin
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#00E5FF").opacity(0.25))
                            .frame(width: 14, height: 14)
                        Circle()
                            .fill(Color(hex: "#00E5FF"))
                            .frame(width: 8, height: 8)
                    }
                    .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(isTracking ? "ORIGIN • \(tripStartTimeString)" : "ORIGIN")
                                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(hex: "#00E5FF").opacity(0.9))
                            Spacer()
                            Text(isTracking ? String(format: "%.2f \(distanceUnit)", displayMiles) : "—")
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.45))
                        }

                        Text(tracker.startAddressString.isEmpty
                             ? (isTracking ? "Resolving address..." : "—")
                             : tracker.startAddressString)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }

                if isTracking {
                    // Connecting Corridor Line
                    HStack(spacing: 10) {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#00E5FF").opacity(0.7), Color(hex: "#00FF88").opacity(0.7)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 2, height: 36)
                            .padding(.leading, 6)

                        HStack(spacing: 5) {
                            Image(systemName: "road.lanes")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color(hex: "#00E5FF"))
                            Text("EN ROUTE")
                                .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                                .foregroundStyle(Color(hex: "#00E5FF"))
                            Spacer()
                            Text(String(format: "%.2f \(distanceUnit) logged", displayMiles))
                                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color(hex: "#091726").opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color(hex: "#00E5FF").opacity(0.25), lineWidth: 1))
                    }

                    // Node 2: Destination (unknown until trip ends)
                    HStack(alignment: .top, spacing: 10) {
                        ZStack {
                            Circle()
                                .strokeBorder(Color(hex: "#00FF88"), lineWidth: 2)
                                .frame(width: 14, height: 14)
                            Circle()
                                .fill(Color(hex: "#00FF88"))
                                .frame(width: 6, height: 6)
                        }
                        .padding(.top, 2)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("DESTINATION")
                                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(hex: "#00FF88"))

                            Text("Recording in progress...")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.5))
                                .italic()
                        }
                    }
                }
            }

            // Trio Telemetry Performance Cards
            HStack(spacing: 8) {
                // 1. Motion Smooth
                telemetryPillCard(
                    icon: "waveform",
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
                    value: String(format: "-%.1f%%", tracker.currentDrainRatePerHour),
                    label: "DRAIN / HOUR",
                    color: Color(hex: "#00FF88")
                )
            }

            // Live Classification Picker (real — not dummy tags)
            if isTracking {
                VStack(alignment: .leading, spacing: 6) {
                    Text("PRE-CLASSIFY THIS TRIP")
                        .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))

                    HStack(spacing: 8) {
                        ForEach(["business", "personal", "medical", "charity"], id: \.self) { cls in
                            Button {
                                liveClassification = cls
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: classIcon(for: cls))
                                        .font(.system(size: 9))
                                    Text(cls.capitalized)
                                        .font(.system(size: 10.5, weight: .bold))
                                }
                                .foregroundStyle(liveClassification == cls ? Color(hex: "#061A13") : Color(hex: "#00FF88"))
                                .padding(.horizontal, 11)
                                .padding(.vertical, 7)
                                .background(
                                    Group {
                                        if liveClassification == cls {
                                            LinearGradient(colors: [Color(hex: "#00FF88"), Color(hex: "#00D670")], startPoint: .leading, endPoint: .trailing)
                                        } else {
                                            LinearGradient(colors: [Color(hex: "#0B1522").opacity(0.85), Color(hex: "#0B1522").opacity(0.85)], startPoint: .leading, endPoint: .trailing)
                                        }
                                    }
                                )
                                .clipShape(Capsule())
                                .overlay(Capsule().strokeBorder(
                                    liveClassification == cls ? Color.clear : Color(hex: "#00FF88").opacity(0.3),
                                    lineWidth: 1
                                ))
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(14)
        .background(
            ZStack {
                Color(hex: "#07111C").opacity(0.88)
                Rectangle().fill(.ultraThinMaterial.opacity(0.5))
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color(hex: "#00E5FF").opacity(0.35), Color(hex: "#00FF88").opacity(0.2), Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.45), radius: 14, y: 7)
    }

    private func telemetryPillCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text(label)
                .font(.system(size: 7.5, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            ZStack {
                Color(hex: "#07121E").opacity(0.85)
                Rectangle().fill(.ultraThinMaterial.opacity(0.4))
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color(hex: "#00E5FF").opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Live Route Map Card

    private var liveRouteMapCard: some View {
        ZStack(alignment: .topLeading) {
            LiveRouteMapView(
                breadcrumbs: tracker.liveBreadcrumbs,
                startCoordinate: tracker.liveBreadcrumbs.first?.coordinate,
                isTracking: isTracking
            )
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color(hex: "#00FF88").opacity(0.6), Color(hex: "#00E5FF").opacity(0.3)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: Color(hex: "#00FF88").opacity(0.15), radius: 16, y: 6)

            // Status pill overlay
            HStack(spacing: 6) {
                Circle()
                    .fill(isTracking ? Color(hex: "#00FF88") : Color.gray)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle().stroke(isTracking ? Color(hex: "#00FF88") : Color.gray, lineWidth: 1)
                            .scaleEffect(isTracking ? 1.6 : 1.0)
                            .opacity(isTracking ? 0.4 : 0)
                            .animation(.easeInOut(duration: 1).repeatForever(), value: isTracking)
                    )
                Text(isTracking ? "LIVE ROUTE" : "NO ACTIVE TRIP")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(isTracking ? Color(hex: "#00FF88") : Color.white.opacity(0.5))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .padding(12)
        }
    }


    // MARK: - Primary Action CTA Button

    private var primaryActionCTA: some View {
        VStack(spacing: 12) {
            if isTracking {
                // ── Stop & Classify ───────────────────────────────────
                Button {
                    tracker.manualStopTrip {
                        selectedTab?.wrappedValue = 1
                    }
                } label: {
                    HStack(spacing: 9) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color(hex: "#061A13"))
                                .frame(width: 22, height: 22)
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Color(hex: "#00FF88"))
                                .frame(width: 10, height: 10)
                        }
                        Text("Stop & Classify Drive")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color(hex: "#061A13"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#00E5FF"), Color(hex: "#00FF88")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: Color(hex: "#00E5FF").opacity(0.55), radius: 12, x: 0, y: 4)
                }
                .buttonStyle(.plain)
            } else {
                // ── Manual Start Trip ─────────────────────────────────
                Button {
                    tracker.manualStartTrip()
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#00FF88").opacity(0.2))
                                .frame(width: 28, height: 28)
                            Image(systemName: "play.fill")
                                .font(.system(size: 13, weight: .black))
                                .foregroundStyle(Color(hex: "#00FF88"))
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Start Trip Manually")
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                            Text("Bypass auto-detection · GPS starts immediately")
                                .font(.system(size: 10, weight: .medium))
                                .opacity(0.7)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(
                        ZStack {
                            Color(hex: "#071A10").opacity(0.95)
                            LinearGradient(
                                colors: [Color(hex: "#00FF88").opacity(0.12), Color.clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        }
                    )
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color(hex: "#00FF88").opacity(0.5), lineWidth: 1.5))
                    .shadow(color: Color(hex: "#00FF88").opacity(0.2), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
                
                Text("Auto-detection is also active in background")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .padding(.top, 4)
    }

    private var tripStartTimeString: String {
        guard let start = tracker.tripStartDate else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "hh:mm a"
        return fmt.string(from: start)
    }
    
    private func classIcon(for cls: String) -> String {
        switch cls {
        case "business":  return "briefcase.fill"
        case "personal":  return "house.fill"
        case "medical":   return "cross.fill"
        case "charity":   return "heart.fill"
        default:          return "tag.fill"
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

