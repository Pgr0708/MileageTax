// RadarView.swift — MileageTax · Tab 1: Radar (Dashboard)
// Obsidian Precision Design System — Exact Match to Master UI Spec
// Real-time telemetry, animated HUD, live 3D route map preview, and IRS write-offs.

import SwiftUI
import CoreData

struct RadarView: View {
    var selectedTab: Binding<Int>? = nil

    @StateObject private var tracker = TripTrackerService.shared
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TripEntity.startDate, ascending: false)],
        predicate: NSPredicate(format: "isInProgress == false"),
        animation: .default)
    private var trips: FetchedResults<TripEntity>

    // Centralized IRS Rate (Single Source of Truth)
    @AppStorage(AppStorageKeys.irsRateOverride) private var irsRate: Double = MileageTaxDefaults.irsRatePerMile

    // Animation States
    @State private var radarPulse: Bool = false
    @State private var borderGlowPhase: Double = 0
    @State private var isRadarPaused: Bool = false

    // Real Metrics calculated live from CoreData Single Source of Truth
    private var ytdMiles: Double {
        trips.filter { $0.tripClassification == .business }.reduce(0) { $0 + $1.totalDistanceMiles }
    }
    private var ytdDeduction: Double {
        trips.filter { $0.tripClassification == .business }.reduce(0) { $0 + $1.taxDeductionValueUSD }
    }
    private var pendingCount: Int {
        trips.filter { $0.needsReview }.count
    }
    private var pendingDeduction: Double {
        trips.filter { $0.needsReview }.reduce(0) { $0 + $1.taxDeductionValueUSD }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // MARK: Cinematic Background Layer extending to top of screen behind Dynamic Island
                backgroundScene

                // MARK: Main Scroll View
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // 1. Tagline Section ("Smarter Miles. Bigger Savings.")
                        taglineSection

                        // 3. YTD Verified Deduction Hero Card
                        ytdHeroCard

                        // 4. Live Drive In Progress Map Card
                        liveDriveMapCard

                        // 5. Route Details Card (Origin & Target)
                        routeDetailsCard

                        // 6. Telemetry Metric Boxes (Trio Grid)
                        telemetryTrioGrid

                        // 7. Action Controls Bar (Pause & End & Classify)
                        actionControlsCard

                        // 8. Drives Pending Review Banner (only if real trips pending)
                        if pendingCount > 0 {
                            pendingReviewBanner
                        }

                        // 9. Telemetry Log Stream
                        telemetryLogStream

                        Spacer(minLength: 120)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, Device.topSafeArea + 58) // safe area + header height
                }
            }
            .navigationBarHidden(true)
            .preferredColorScheme(.dark)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    radarPulse = true
                }
                withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                    borderGlowPhase = 1.0
                }
            }
        }
    }

    // MARK: - 1. Cinematic Background Layer

    private var backgroundScene: some View {
        ZStack {
            Color(hex: "#06090E").ignoresSafeArea()

            // Mountain scenic wallpaper extending to top of screen behind Dynamic Island
            Image("radar_bg_mountain")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color(hex: "#06090E").opacity(0.12),
                            Color(hex: "#06090E").opacity(0.85),
                            Color(hex: "#06090E")
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Top ambient teal/emerald aurora glow
            RadialGradient(
                colors: [Color(hex: "#00E5FF").opacity(0.14), Color.clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 280
            )
            .ignoresSafeArea()

            // Bottom-right neon emerald atmospheric glow
            RadialGradient(
                colors: [Color(hex: "#00FF88").opacity(0.08), Color.clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 360
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - 3. Tagline Section ("Smarter Miles. Bigger Savings.")

    private var taglineSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Smarter Miles.")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Bigger Savings.")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                // Neon Emerald Underline Bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: "#00FF88"))
                    .frame(width: 38, height: 3.5)
                    .shadow(color: Color(hex: "#00FF88").opacity(0.6), radius: 4, x: 0, y: 1)
                    .padding(.top, 2)
            }

            Spacer()
        }
        .padding(.top, 2)
        .padding(.bottom, 4)
    }

    // MARK: - 4. YTD Verified Deduction (Hero Card with Rising Chart)

    private var ytdHeroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top Row: Title + Growth vs Q3 Pill
            HStack(alignment: .top) {
                HStack(spacing: 6) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(hex: "#00E5FF"))

                    Text("YTD VERIFIED DEDUCTION")
                        .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                        .tracking(0.6)
                }

                Spacer()

                // +18.4% vs Q3 Pill
                HStack(spacing: 5) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("+18.4% vs")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(Color(hex: "#00FF88"))
                        Text("Q3")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(Color(hex: "#00FF88").opacity(0.85))
                    }

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Color(hex: "#00FF88"))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(hex: "#06221A").opacity(0.85))
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(Color(hex: "#00FF88").opacity(0.35), lineWidth: 1)
                )
            }

            // Center: Big Hero Number
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("$")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: "#00FF88"))
                    .shadow(color: Color(hex: "#00FF88").opacity(0.35), radius: 8)

                Text(String(format: "%.2f", ytdDeduction))
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }

            // Bottom Row: Business Miles Logged
            HStack(spacing: 6) {
                Image(systemName: "location.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: "#00FF88"))

                VStack(alignment: .leading, spacing: 1) {
                    Text(String(format: "%.1f", ytdMiles) + "  BUSINESS MILES")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)

                    Text("LOGGED")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Image("radar_ytd_chart_card")
                .resizable()
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color(hex: "#00E5FF").opacity(0.6),
                            Color(hex: "#00FF88").opacity(0.3),
                            Color.white.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: Color.black.opacity(0.5), radius: 14, x: 0, y: 7)
    }

    // MARK: - 5. Live Drive In Progress (Mission Control Map Card)

    private var liveDriveMapCard: some View {
        VStack(spacing: 10) {
            // Header: Live Indicator + IRS Rate Pill
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#00E5FF").opacity(0.25))
                            .frame(width: 18, height: 18)
                            .scaleEffect(radarPulse ? 1.3 : 1.0)
                            .opacity(radarPulse ? 0.3 : 0.8)

                        Circle()
                            .fill(Color(hex: "#00FF88"))
                            .frame(width: 9, height: 9)
                            .shadow(color: Color(hex: "#00FF88"), radius: 5)
                    }

                    Text("LIVE DRIVE IN PROGRESS")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#00E5FF"), Color(hex: "#00FF88")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .tracking(0.6)
                }

                Spacer()

                Text("IRS 2026: 67¢/MI")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    )
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            // Mini 3D Map Route View with Overlays
            ZStack(alignment: .bottom) {
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 140)
                    .overlay(
                        Image("radar_live_map_route")
                            .resizable()
                            .scaledToFill()
                    )
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.55)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // Top Right Overlay: GPS Fix Pill
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "cellularbars")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color(hex: "#00E5FF"))
                            Text(tracker.state == .activeTracking ? String(format: "GPS Fix: ±%.1fm", tracker.horizontalAccuracyMeters) : "GPS Fix: —")
                                .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#08121C").opacity(0.85))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                        )
                        .padding(10)
                    }
                    Spacer()
                }

                // Bottom Overlay Badges: Highway and Bluetooth OBD-II
                HStack {
                    // Left: Highway code
                    HStack(spacing: 5) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(hex: "#00FF88"))
                        VStack(alignment: .leading, spacing: 0) {
                            Text("US-101 S")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(Color(hex: "#00FF88"))
                            Text("FLAT1INPATH")
                                .font(.system(size: 7.5, weight: .heavy, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }

                    Spacer()

                    // Right: Auto-Detect Bluetooth OBD-II
                    HStack(spacing: 4) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 9))
                            .foregroundStyle(Color(hex: "#00E5FF"))
                        Text("Auto-Detect: Bluetooth OBD-II")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#08121C").opacity(0.85))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    )
                }
                .padding(10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(Color(hex: "#0A1018").opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color(hex: "#00E5FF").opacity(0.4),
                            Color(hex: "#00FF88").opacity(0.2),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: Color.black.opacity(0.5), radius: 16, x: 0, y: 8)
    }

    // MARK: - 6. Route Details Card (Origin & Target)

    private var routeDetailsCard: some View {
        HStack(spacing: 12) {
            // Left: Scenic Route Thumbnail
            Image("radar_route_thumbnail")
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )

            // Right: Origin and Target Details
            VStack(alignment: .leading, spacing: 6) {
                // Origin Row
                HStack(alignment: .center, spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: "#00FF88"))

                    Text("ORIGIN")
                        .font(.system(size: 8.5, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))

                    Spacer()

                    Group {
                        if tracker.state == .activeTracking {
                            Text(Date(timeIntervalSinceNow: -tracker.liveDurationSeconds), style: .time)
                        } else {
                            Text("—")
                        }
                    }
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                }

                Text(tracker.startAddressString.isEmpty ? (tracker.state == .activeTracking ? "Resolving..." : "—") : tracker.startAddressString)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                // Target Row
                HStack(alignment: .center, spacing: 6) {
                    Image(systemName: "scope")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(hex: "#00E5FF"))

                    Text("TARGET")
                        .font(.system(size: 8.5, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                }

                HStack(spacing: 4) {
                    Text(tracker.targetAddressString.isEmpty ? (tracker.state == .activeTracking ? "In progress..." : "Waiting for trip") : tracker.targetAddressString)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if tracker.state == .activeTracking {
                        Text("(En Route)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(hex: "#00E5FF"))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
        }
        .padding(12)
        .background(Color(hex: "#0A1018").opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 6)
    }

    // MARK: - 7. Telemetry Metric Boxes (Trio Grid)

    private var telemetryTrioGrid: some View {
        HStack(spacing: 8) {
            // 1. Distance — real value or 0.0 default
            metricBox(
                icon: "point.topleft.down.to.point.bottomright.curvepath.fill",
                label: "DISTANCE",
                value: String(format: "%.1f", tracker.liveDistanceMiles),
                unit: "MILES",
                accent: Color(hex: "#00FF88")
            )

            // 2. Speed — real value or 0 default
            metricBox(
                icon: "speedometer",
                label: "SPEED",
                value: String(format: "%.0f", tracker.currentSpeedMph),
                unit: "MPH",
                accent: Color.white
            )

            // 3. Tax Yield — real value or $0.00 default
            metricBox(
                icon: "banknote.fill",
                label: "TAX YIELD",
                value: String(format: "+$%.2f", tracker.liveDeductionUSD),
                unit: "WRITE-OFF",
                accent: Color(hex: "#00FF88")
            )
        }
    }

    // MARK: - 8. Action Controls Bar (Pause & End & Classify)

    private var actionControlsCard: some View {
        HStack(spacing: 12) {
            // Pause Radar Button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isRadarPaused.toggle()
                }
                // Pause = stop tracking; resume = re-enable location updates via AppLifecycle
                if isRadarPaused {
                    tracker.stop()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isRadarPaused ? "play.circle.fill" : "pause.circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(isRadarPaused ? "Resume" : "Pause\nRadar")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            // Subtle vertical separator
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 1, height: 26)

            // End & Classify Button (Primary Glowing Neon Emerald)
            Button {
                tracker.stop()
                selectedTab?.wrappedValue = 1
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 14, weight: .black))

                    Text("End & Classify")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .black))
                }
                .foregroundStyle(Color(hex: "#061A13"))
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#00FF88"), Color(hex: "#00F076")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: Color(hex: "#00FF88").opacity(0.35), radius: 10, x: 0, y: 4)
            }
        }
        .padding(8)
        .background(Color(hex: "#0C141E").opacity(0.85))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 6)
    }

    private func metricBox(icon: String, label: String, value: String, unit: String, accent: Color) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.4))
                Text(label)
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Text(value)
                .font(.system(size: 19, weight: .black, design: .rounded))
                .foregroundStyle(accent)

            Text(unit)
                .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(hex: "#0A1018").opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color(hex: "#00E5FF").opacity(0.35), Color(hex: "#00FF88").opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
    }

    // MARK: - 9. Drives Pending Review Banner

    private var pendingReviewBanner: some View {
        Button {
            selectedTab?.wrappedValue = 1
        } label: {
            HStack(spacing: 12) {
                // Document / Receipt Teal Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(hex: "#0A2822"))
                        .frame(width: 44, height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color(hex: "#00FF88").opacity(0.3), lineWidth: 1)
                        )

                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(hex: "#00FF88"))
                }

                // Middle Text: Count & Unclaimed write-off
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: "#00FF88"))
                            .frame(width: 6, height: 6)

                        Text("\(pendingCount) Drive\(pendingCount == 1 ? "" : "s") Pending")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }

                    Text(String(format: "+$%.2f Unclaimed Write Off", pendingDeduction))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(hex: "#00E5FF").opacity(0.85))
                }

                Spacer()

                // Review Deck Button
                HStack(spacing: 4) {
                    Text("Review\nDeck")
                        .font(.system(size: 10.5, weight: .bold))
                        .multilineTextAlignment(.trailing)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(Color(hex: "#00E5FF"))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(hex: "#081D26").opacity(0.8))
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(Color(hex: "#00E5FF").opacity(0.25), lineWidth: 1)
                )
            }
            .padding(12)
            .background(Color(hex: "#09141D").opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color(hex: "#00FF88").opacity(0.4), Color(hex: "#00E5FF").opacity(0.15)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 6)
        }
    }

    // MARK: - 7. Telemetry Log Stream

    private var telemetryLogStream: some View {
        VStack(spacing: 12) {
            // Header: Section title + View All button
            HStack {
                Text("TELEMETRY LOG STREAM")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
                    .tracking(1.2)

                Spacer()

                Button {
                    selectedTab?.wrappedValue = 3
                } label: {
                    HStack(spacing: 4) {
                        Text("View All")
                            .font(.system(size: 11.5, weight: .bold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(Color(hex: "#00E5FF"))
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)

            // Log Items (show live trips if available, otherwise high-end mock telemetry rows)
            if trips.isEmpty {
                // Mock Card 1: SFO Airport to Union Square
                telemetryCard(
                    imageName: "radar_route_thumbnail",
                    timestamp: "Yesterday  •  16:40",
                    icon: "airplane",
                    title: "SFO Airport to Union Square",
                    tag1: "#ClientMeeting",
                    tag1Color: Color(hex: "#00E5FF"),
                    tag2: "Auto-Matched 98%",
                    yieldText: "+$12.20 YIELD",
                    distanceText: "18.2 mi"
                )

                // Mock Card 2: Palo Alto to Mountain View
                telemetryCard(
                    imageName: "radar_route_thumbnail",
                    timestamp: "Oct 24  •  09:12",
                    icon: "car.fill",
                    title: "Palo Alto to Mountain View",
                    tag1: "CarPlay Integrated",
                    tag1Color: Color(hex: "#00E5FF"),
                    tag2: "Sand Hill Partners",
                    yieldText: "+$4.28 YIELD",
                    distanceText: "6.4 mi"
                )
            } else {
                ForEach(trips.prefix(5), id: \.objectID) { trip in
                    realTripTelemetryCard(trip: trip)
                }
            }
        }
    }

    private func telemetryCard(
        imageName: String,
        timestamp: String,
        icon: String,
        title: String,
        tag1: String,
        tag1Color: Color,
        tag2: String,
        yieldText: String,
        distanceText: String) -> some View {

        HStack(spacing: 12) {
            // Scenic Thumbnail
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )

            // Title and Details
            VStack(alignment: .leading, spacing: 4) {
                Text(timestamp)
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))

                HStack(spacing: 5) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                // Tags
                HStack(spacing: 6) {
                    Text(tag1)
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(tag1Color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(tag1Color.opacity(0.12))
                        .clipShape(Capsule())

                    Text(tag2)
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Capsule())
                }
            }

            Spacer()

            // Right: Yield & Distance
            VStack(alignment: .trailing, spacing: 4) {
                Text(yieldText)
                    .font(.system(size: 11.5, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: "#00FF88"))

                HStack(spacing: 2) {
                    Text(distanceText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
        }
        .padding(12)
        .background(Color(hex: "#0A1018").opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func realTripTelemetryCard(trip: TripEntity) -> some View {
        HStack(spacing: 12) {
            // Scenic Thumbnail
            Image("radar_route_thumbnail")
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )

            // Title and Details
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.startDate ?? Date(), style: .date)
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))

                HStack(spacing: 5) {
                    Image(systemName: trip.tripClassification == .business ? "briefcase.fill" : "house.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(trip.tripClassification == .business ? Color(hex: "#00FF88") : Color(hex: "#7B4FFF"))
                    Text(trip.endAddress ?? "Trip Record")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                // Tags
                HStack(spacing: 6) {
                    Text(trip.tripClassification.rawValue.capitalized)
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(trip.tripClassification == .business ? Color(hex: "#00FF88") : Color(hex: "#7B4FFF"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            (trip.tripClassification == .business ? Color(hex: "#00FF88") : Color(hex: "#7B4FFF")).opacity(0.12)
                        )
                        .clipShape(Capsule())

                    if let purpose = trip.businessPurpose, !purpose.isEmpty {
                        Text(purpose)
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            // Right: Yield & Distance
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "+$%.2f YIELD", trip.taxDeductionValueUSD))
                    .font(.system(size: 11.5, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: "#00FF88"))

                HStack(spacing: 2) {
                    Text(String(format: "%.1f mi", trip.totalDistanceMiles))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
        }
        .padding(12)
        .background(Color(hex: "#0A1018").opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}
