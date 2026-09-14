// RadarView.swift — MileageTax · Tab 1: Radar (Dashboard)
// Live stats hero, animated ring, earnings projector, recent trips.

import SwiftUI
import CoreData

struct RadarView: View {
    @StateObject private var tracker = TripTrackerService.shared
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TripEntity.startDate, ascending: false)],
        predicate: NSPredicate(format: "isInProgress == false"),
        animation: .default)
    private var trips: FetchedResults<TripEntity>

    @State private var ringAngle: Double = 0
    @State private var pulseScale: CGFloat = 1
    @State private var showProfile = false
    @State private var showSettings = false

    // IRS rate for 2024
    private let irsRate = 0.67

    private var ytdMiles: Double  { trips.reduce(0) { $0 + $1.totalDistanceMiles } }
    private var ytdDeduction: Double { trips.reduce(0) { $0 + $1.taxDeductionValueUSD } }
    private var businessTrips: Int { trips.filter { $0.classification == "business" }.count }
    private var pendingCount: Int  { trips.filter { $0.needsReview }.count }
    private var thisWeekMiles: Double {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return trips.filter { ($0.startDate ?? .distantPast) >= cutoff }
                    .reduce(0) { $0 + $1.totalDistanceMiles }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundLayer
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.lg) {
                        headerBar
                        heroCard
                        statsRow
                        if pendingCount > 0 { reviewBanner }
                        recentTripsSection
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.sm)
                }
            }
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            Color.obsidian.ignoresSafeArea()
            // subtle radial glow at top
            RadialGradient(
                colors: [Color.neonEmerald.opacity(0.08), .clear],
                center: .top, startRadius: 0, endRadius: 300)
            .ignoresSafeArea()
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Button { showProfile = true } label: {
                ZStack {
                    Circle()
                        .fill(AppGradient.emeraldPulse)
                        .frame(width: 40, height: 40)
                    Text("M")
                        .font(.headline)
                        .foregroundStyle(Color.textOnAccent)
                }
                .emeraldGlow(radius: 6)
            }
            Spacer()
            VStack(spacing: 2) {
                Text("MileageTax")
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)
                Text(Date(), style: .date)
                    .font(.captionText)
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 40, height: 40)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        ZStack {
            // Dark card bg
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#0D1F1A"), Color(hex: "#0A1410")],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                        .strokeBorder(Color.neonEmerald.opacity(0.2), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.5), radius: 20, y: 10)

            VStack(spacing: AppSpacing.lg) {
                // Ring + Main Metric
                ZStack {
                    ringView
                    VStack(spacing: 4) {
                        if tracker.state == .activeTracking {
                            Text(String(format: "%.1f", tracker.liveDistanceMiles))
                                .font(.displayHero)
                                .foregroundStyle(Color.neonEmerald)
                                .emeraldGlow()
                                .contentTransition(.numericText())
                            Text("miles · LIVE")
                                .font(.captionText)
                                .foregroundStyle(Color.electricCyan)
                                .cyanGlow(radius: 4)
                        } else {
                            Text(String(format: "%.0f", ytdMiles))
                                .font(.displayHero)
                                .foregroundStyle(Color.textPrimary)
                                .contentTransition(.numericText())
                            Text("miles YTD")
                                .font(.captionText)
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
                }

                // Deduction
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundStyle(AppGradient.goldGradient)
                    Text(String(format: "$%.2f", ytdDeduction))
                        .font(.displayMedium)
                        .foregroundStyle(Color.textPrimary)
                    Text("estimated deduction")
                        .font(.captionText)
                        .foregroundStyle(Color.textSecondary)
                        .alignmentGuide(.lastTextBaseline) { d in d[.lastTextBaseline] }
                }

                // Status pill
                statusPill
            }
            .padding(AppSpacing.lg)
        }
    }

    private var ringView: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: 10)
                .frame(width: 180, height: 180)
            // Progress arc (based on 1000 mi goal)
            let progress = min(ytdMiles / 1000.0, 1.0)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [Color.neonEmerald, Color.electricCyan, Color.neonEmerald],
                        center: .center),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .frame(width: 180, height: 180)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.2), value: ytdMiles)
                .emeraldGlow()
            // Pulse dot when live
            if tracker.state == .activeTracking {
                Circle()
                    .fill(Color.crimsonPulse)
                    .frame(width: 14, height: 14)
                    .offset(y: -90)
                    .rotationEffect(.degrees(Double(ytdMiles / 1000.0) * 360 - 90))
                    .scaleEffect(pulseScale)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                            pulseScale = 1.4
                        }
                    }
            }
        }
        .frame(width: 200, height: 200)
    }

    private var statusPill: some View {
        HStack(spacing: AppSpacing.sm) {
            switch tracker.state {
            case .activeTracking:
                Circle().fill(Color.crimsonPulse).frame(width: 8, height: 8)
                    .overlay(Circle().stroke(Color.crimsonPulse.opacity(0.4), lineWidth: 4))
                Text("LIVE TRACKING")
                    .font(.captionText).foregroundStyle(Color.crimsonPulse)
            case .verifyingMotion:
                Circle().fill(Color.amberGlow).frame(width: 8, height: 8)
                Text("Verifying Motion")
                    .font(.captionText).foregroundStyle(Color.amberGlow)
            case .idleBuffer:
                Circle().fill(Color.amberGlow).frame(width: 8, height: 8)
                Text("Idle Buffer")
                    .font(.captionText).foregroundStyle(Color.amberGlow)
            default:
                Circle().fill(Color.textTertiary).frame(width: 8, height: 8)
                Text("Monitoring")
                    .font(.captionText).foregroundStyle(Color.textSecondary)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.06))
                .overlay(Capsule().strokeBorder(Color.glassBorder, lineWidth: 1)))
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: AppSpacing.sm) {
            statCard(
                icon: "briefcase.fill",
                value: "\(businessTrips)",
                label: "Business",
                gradient: AppGradient.emeraldPulse)
            statCard(
                icon: "calendar",
                value: String(format: "%.0f", thisWeekMiles),
                label: "This Week",
                gradient: AppGradient.cyanEmerald)
            statCard(
                icon: "percent",
                value: businessTrips > 0 && trips.count > 0
                    ? "\(Int(Double(businessTrips) / Double(trips.count) * 100))%"
                    : "–",
                label: "Business %",
                gradient: AppGradient.purpleGradient)
        }
    }

    private func statCard(icon: String,
                          value: String,
                          label: String,
                          gradient: LinearGradient) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(gradient)
            Text(value)
                .font(.displayMedium)
                .foregroundStyle(Color.textPrimary)
                .contentTransition(.numericText())
            Text(label)
                .font(.micro)
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.md)
        .glassCard(radius: AppRadius.md)
    }

    // MARK: - Review Banner

    private var reviewBanner: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.amberGlow)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(pendingCount) trips need review")
                    .font(.subheadline)
                    .foregroundStyle(Color.textPrimary)
                Text("Tap to classify and lock in deductions")
                    .font(.captionText)
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(Color.amberGlow)
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                .fill(Color.amberGlow.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                        .strokeBorder(Color.amberGlow.opacity(0.3), lineWidth: 1)))
    }

    // MARK: - Recent Trips

    private var recentTripsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("Recent Trips")
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text("See All")
                    .font(.captionText)
                    .foregroundStyle(Color.neonEmerald)
            }

            if trips.isEmpty {
                emptyTripsPlaceholder
            } else {
                ForEach(Array(trips.prefix(5)), id: \.objectID) { trip in
                    TripRowCard(trip: trip)
                }
            }
        }
    }

    private var emptyTripsPlaceholder: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "car.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.neonEmerald.opacity(0.4))
                .emeraldGlow(radius: 20, opacity: 0.2)
            Text("No trips yet")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
            Text("Start driving and MileageTax will automatically detect and log your trips.")
                .font(.bodyText)
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, AppSpacing.xxl)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Trip Row Card

struct TripRowCard: View {
    let trip: TripEntity

    private var classColor: Color {
        switch trip.classification {
        case "business": return .neonEmerald
        case "personal": return .deepPurple
        default:         return .amberGlow
        }
    }

    private var classIcon: String {
        switch trip.classification {
        case "business": return "briefcase.fill"
        case "personal": return "house.fill"
        default:         return "questionmark.circle.fill"
        }
    }

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(classColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: classIcon)
                    .font(.system(size: 18))
                    .foregroundStyle(classColor)
            }

            // Route info
            VStack(alignment: .leading, spacing: 3) {
                Text(trip.startAddress ?? "Unknown Start")
                    .font(.subheadline)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Text("→ " + (trip.endAddress ?? "Unknown End"))
                    .font(.captionText)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
                if let date = trip.startDate {
                    Text(date, style: .relative)
                        .font(.micro)
                        .foregroundStyle(Color.textTertiary)
                }
            }

            Spacer()

            // Metrics
            VStack(alignment: .trailing, spacing: 3) {
                Text(String(format: "%.1f mi", trip.totalDistanceMiles))
                    .font(.subheadline)
                    .foregroundStyle(Color.textPrimary)
                Text(String(format: "$%.2f", trip.taxDeductionValueUSD))
                    .font(.captionText)
                    .foregroundStyle(Color.neonEmerald)
            }
        }
        .padding(AppSpacing.md)
        .glassCard(radius: AppRadius.md)
    }
}
