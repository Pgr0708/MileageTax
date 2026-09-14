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
    @State private var showNotificationSheet: Bool = false
    @State private var showProfileSheet: Bool = false
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
                // MARK: Cinematic Background Layer
                backgroundScene

                // MARK: Main Scroll View
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // 1. Header Bar
                        topHeaderBar

                        // 2. Radar Status Pill Bar
                        statusPillBar

                        // 3. YTD Verified Deduction Hero Card
                        ytdHeroCard

                        // 4. Live Drive In Progress Card (Mission Control)
                        liveDriveCard

                        // 5. Drives Pending Review Banner
                        pendingReviewBanner

                        // 6. Telemetry Log Stream
                        telemetryLogStream

                        Spacer(minLength: 110)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }
            }
        }
        .sheet(isPresented: $showProfileSheet) {
            ProfileView()
        }
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

    // MARK: - 1. Cinematic Background Layer

    private var backgroundScene: some View {
        ZStack {
            // Deep base obsidian
            Color(hex: "#06090E").ignoresSafeArea()

            // Mountain scenic wallpaper at top
            GeometryReader { geo in
                Image("radar_bg_mountain")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height * 0.75, alignment: .top)
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color(hex: "#06090E").opacity(0.4),
                                Color(hex: "#06090E").opacity(0.85),
                                Color(hex: "#06090E")
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .ignoresSafeArea()
            }

            // Top ambient teal/emerald aurora glow
            RadialGradient(
                colors: [Color(hex: "#00E5FF").opacity(0.12), Color.clear],
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

    // MARK: - 2. Top Header Bar

    private var topHeaderBar: some View {
        HStack(alignment: .center, spacing: 12) {
            // Left: Logo & Brand
            HStack(spacing: 10) {
                // High-tech rounded app icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(hex: "#0C141E"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color(hex: "#00E5FF").opacity(0.6), Color(hex: "#00FF88").opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.2
                                )
                        )
                        .frame(width: 44, height: 44)
                        .shadow(color: Color(hex: "#00E5FF").opacity(0.25), radius: 8, x: 0, y: 3)

                    // Stylized M mark
                    Image(systemName: "m.circle.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#00E5FF"), Color(hex: "#00FF88")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Mileage")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        + Text("Tax")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "#00FF88"))

                        // PRO Badge
                        Text("PRO")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(Color(hex: "#00E5FF"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#00E5FF").opacity(0.12))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color(hex: "#00E5FF").opacity(0.4), lineWidth: 1)
                            )
                    }

                    Text("TRACK  /  LOG  /  SAVE")
                        .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                        .tracking(1.8)
                }
            }

            Spacer()

            // Right: Notification Bell & Profile Avatar Buttons
            HStack(spacing: 10) {
                // Notification Button with live red/green indicator
                Button {
                    showNotificationSheet = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Circle()
                            .fill(Color(hex: "#0E1622").opacity(0.85))
                            .frame(width: 42, height: 42)
                            .overlay(
                                Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                            )

                        Image(systemName: "bell")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(width: 42, height: 42)

                        // Glowing Notification Dot
                        Circle()
                            .fill(Color(hex: "#00FF88"))
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .stroke(Color(hex: "#0C141E"), lineWidth: 1.5)
                            )
                            .shadow(color: Color(hex: "#00FF88"), radius: 4)
                            .offset(x: -4, y: 4)
                    }
                }

                // Profile Avatar Button
                Button {
                    showProfileSheet = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#0E1622").opacity(0.85))
                            .frame(width: 42, height: 42)
                            .overlay(
                                Circle().strokeBorder(Color(hex: "#00E5FF").opacity(0.35), lineWidth: 1)
                            )

                        Image(systemName: "person.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "#00E5FF"), Color(hex: "#00FF88")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - 3. Status Pill Bar

    private var statusPillBar: some View {
        HStack(spacing: 10) {
            // Pill 1: Automatic Radar Armed
            HStack(spacing: 7) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#00FF88").opacity(0.3))
                        .frame(width: 14, height: 14)
                        .scaleEffect(radarPulse ? 1.4 : 1.0)
                        .opacity(radarPulse ? 0.3 : 0.8)

                    Circle()
                        .fill(Color(hex: "#00FF88"))
                        .frame(width: 7, height: 7)
                        .shadow(color: Color(hex: "#00FF88"), radius: 4)
                }

                Text("AUTOMATIC RADAR ARMED")
                    .font(.system(size: 9.5, weight: .heavy))
                    .foregroundStyle(Color(hex: "#00FF88"))
                    .tracking(0.6)

                // Waveform telemetry icon
                Image(systemName: "waveform.path")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: "#00FF88").opacity(0.8))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(hex: "#071B14").opacity(0.9))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color(hex: "#00FF88").opacity(0.28), lineWidth: 1)
            )

            Spacer()

            // Pill 2: 1.1%/hr CoreMotion Battery Consumption
            HStack(spacing: 5) {
                Image(systemName: "bolt.badge.clock")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: "#00E5FF"))

                Text(TelemetryBenchmark.proDrainPerHourString)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("CoreMotion")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Color(hex: "#00E5FF").opacity(0.8))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(hex: "#0C141E").opacity(0.8))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }

    // MARK: - 4. YTD Verified Deduction (Hero Card)

    private var ytdHeroCard: some View {
        ZStack(alignment: .topLeading) {
            // Card Scenic Background with dark glass blend
            GeometryReader { geo in
                Image("radar_bg_mountain")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color(hex: "#0A131E").opacity(0.75),
                                Color(hex: "#070E18").opacity(0.92)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 14) {
                // Top Row: Title + IRS Standard Pill
                HStack {
                    Text("YTD  VERIFIED DEDUCTION")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .tracking(0.8)

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(hex: "#00E5FF"))

                        Text("IRS Standard")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )
                }

                // Center: Big Hero Number
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("$")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(Color(hex: "#00FF88"))
                        .shadow(color: Color(hex: "#00FF88").opacity(0.4), radius: 10)

                    Text(String(format: "%.2f", ytdDeduction))
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }

                // Bottom Row: Business Miles + Growth vs Q3
                HStack(alignment: .bottom) {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(hex: "#00FF88"))

                        VStack(alignment: .leading, spacing: 1) {
                            Text(String(format: "%.1f", ytdMiles) + "  BUSINESS MILES")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)

                            Text("LOGGED")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("+18.4% vs")
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color(hex: "#00FF88"))
                            Text("Q3")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color(hex: "#00FF88").opacity(0.8))
                        }

                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(Color(hex: "#00FF88"))
                    }
                }
            }
            .padding(18)
        }
        .frame(height: 165)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1.2)
        )
        .shadow(color: Color.black.opacity(0.5), radius: 16, x: 0, y: 8)
    }

    // MARK: - 5. Live Drive In Progress (Mission Control)

    private var liveDriveCard: some View {
        VStack(spacing: 14) {
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
            .padding(.top, 16)

            // Mini 3D Map Route View
            ZStack(alignment: .bottom) {
                // Map Illustration
                Image("radar_live_map_route")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 145)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // Overlay Top Right: GPS Fix
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "cellularbars")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color(hex: "#00E5FF"))
                            Text(String(format: "GPS Fix: ±%.1fm", tracker.horizontalAccuracyMeters))
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

                // Overlay Bottom Badges: Highway and Bluetooth OBD-II
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
                            Text("FLATHIRPATH")
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
            .padding(.horizontal, 14)

            // Origin & Target Route Section
            VStack(spacing: 10) {
                // Origin
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(hex: "#00FF88"))
                        .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("ORIGIN")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))

                        Text(tracker.startAddressString)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    Text("11:15 AM")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }

                // Target
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "scope")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color(hex: "#00E5FF"))
                        .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("TARGET")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))

                        HStack(spacing: 4) {
                            Text(tracker.targetAddressString)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)

                            Text("(En Route)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(hex: "#00E5FF"))
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)

            // 3 Telemetry Metric Boxes (Trio Grid)
            HStack(spacing: 8) {
                // 1. Distance
                metricBox(
                    icon: "point.topleft.down.to.point.bottomright.curvepath.fill",
                    label: "DISTANCE",
                    value: tracker.liveDistanceMiles > 0 ? String(format: "%.1f", tracker.liveDistanceMiles) : "14.2",
                    unit: "MILES",
                    accent: Color(hex: "#00E5FF")
                )

                // 2. Speed
                metricBox(
                    icon: "speedometer",
                    label: "SPEED",
                    value: tracker.currentSpeedMph > 0 ? String(format: "%.0f", tracker.currentSpeedMph) : "42",
                    unit: "MPH CRUISE",
                    accent: Color.white
                )

                // 3. Tax Yield
                metricBox(
                    icon: "banknote.fill",
                    label: "TAX YIELD",
                    value: tracker.liveDeductionUSD > 0 ? String(format: "+$%.2f", tracker.liveDeductionUSD) : "+$9.51",
                    unit: "WRITE-OFF",
                    accent: Color(hex: "#00FF88")
                )
            }
            .padding(.horizontal, 14)

            // Action Buttons (Pause & End & Classify)
            HStack(spacing: 10) {
                // Pause Button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isRadarPaused.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isRadarPaused ? "play.circle.fill" : "pause.circle")
                            .font(.system(size: 16, weight: .semibold))
                        Text(isRadarPaused ? "Resume" : "Pause\nRadar")
                            .font(.system(size: 11, weight: .bold))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#101824").opacity(0.85))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    )
                }

                // End & Classify Button (Primary Glowing Neon Emerald)
                Button {
                    tracker.stop()
                    selectedTab?.wrappedValue = 1
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 13, weight: .black))
                        Text("End & Classify")
                            .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .black))
                    }
                    .foregroundStyle(Color(hex: "#061A13"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#00FF88"), Color(hex: "#00D670")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: Color(hex: "#00FF88").opacity(0.35), radius: 10, x: 0, y: 4)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 16)
        }
        .background(Color(hex: "#0A1018").opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
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
                    lineWidth: 1.4
                )
        )
        .shadow(color: Color.black.opacity(0.6), radius: 20, x: 0, y: 10)
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
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(accent)

            Text(unit)
                .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(hex: "#0E1622").opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - 6. Drives Pending Review Banner

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

                        Text("\(pendingCount) Drives Pending")
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
                    imageName: "radar_bg_mountain",
                    timestamp: "Yesterday • 16:40",
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
                    imageName: "radar_live_map_route",
                    timestamp: "Oct 24 • 09:12",
                    icon: "car.fill",
                    title: "Palo Alto to Mountain View",
                    tag1: "CarPlay Integrated",
                    tag1Color: Color(hex: "#00FF88"),
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
            Image("radar_live_map_route")
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
