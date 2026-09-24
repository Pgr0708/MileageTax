//
//  VaultView.swift
//  MileageTax · Tab 4: Vault (Schedule C / Export)
//  Obsidian Precision Design System · Exact Match to Spec
//

import SwiftUI
import CoreData
import UIKit

// MARK: - Filter Preset

enum VaultFilterPreset: String, CaseIterable, Identifiable {
    case lastWeek    = "Last Week"
    case lastMonth   = "Last Month"
    case last6Months = "Last 6 Months"
    case lastYear    = "Last Year"
    case thisTaxYear = "This Tax Year"
    case custom      = "Custom Range"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .lastWeek:    return "calendar"
        case .lastMonth:   return "calendar.badge.clock"
        case .last6Months: return "chart.bar.xaxis"
        case .lastYear:    return "calendar.badge.checkmark"
        case .thisTaxYear: return "dollarsign.circle"
        case .custom:      return "slider.horizontal.3"
        }
    }

    func dateRange(from now: Date = Date()) -> (start: Date, end: Date) {
        let cal = Calendar.current
        switch self {
        case .lastWeek:
            return (cal.date(byAdding: .day, value: -7, to: now) ?? now, now)
        case .lastMonth:
            return (cal.date(byAdding: .day, value: -30, to: now) ?? now, now)
        case .last6Months:
            return (cal.date(byAdding: .month, value: -6, to: now) ?? now, now)
        case .lastYear:
            return (cal.date(byAdding: .year, value: -1, to: now) ?? now, now)
        case .thisTaxYear:
            let year = cal.component(.year, from: now)
            let jan1 = cal.date(from: DateComponents(year: year, month: 1, day: 1)) ?? now
            return (jan1, now)
        case .custom:
            // caller provides custom dates; return full range as fallback
            return (cal.date(byAdding: .year, value: -10, to: now) ?? now, now)
        }
    }
}

struct VaultView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TripEntity.startDate, ascending: false)],
        predicate: NSPredicate(format: "isInProgress == false"),
        animation: .default)
    private var allTrips: FetchedResults<TripEntity>

    @State private var selectedVaultTrip: TripEntity? = nil
    @State private var showExportHub = false
    @AppStorage(AppStorageKeys.irsRateOverride)  private var irsRate: Double        = MileageTaxDefaults.irsRatePerMile
    @AppStorage(AppStorageKeys.currencySymbol)    private var currencySymbol: String  = MileageTaxDefaults.defaultCurrencySymbol
    @AppStorage(AppStorageKeys.distanceUnit)      private var distanceUnit: String    = MileageTaxDefaults.defaultDistanceUnit

    // Filter State
    @State private var selectedFilter: VaultFilterPreset = .thisTaxYear
    @State private var customStart: Date = {
        let cal = Calendar.current
        let year = cal.component(.year, from: Date())
        return cal.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date()
    }()
    @State private var customEnd: Date = Date()
    @State private var showCustomDateSheet = false

    // Export State
    @State private var showExportShare = false
    @State private var exportURL: URL? = nil

    // MARK: - Computed Filter Range

    private var activeYear: Int {
        Calendar.current.component(.year, from: activeRange.end)
    }

    private var activeRange: (start: Date, end: Date) {
        if selectedFilter == .custom {
            return (customStart, customEnd)
        }
        return selectedFilter.dateRange()
    }

    private var filterLabel: String {
        if selectedFilter == .custom {
            let fmt = DateFormatter()
            fmt.dateFormat = "MMM d"
            return "\(fmt.string(from: customStart)) – \(fmt.string(from: customEnd))"
        }
        return selectedFilter.rawValue
    }

    // MARK: - Filtered Data

    private var filteredBusinessTrips: [TripEntity] {
        let (start, end) = activeRange
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end
        return allTrips.filter {
            guard $0.tripClassification == .business, let d = $0.startDate else { return false }
            return d >= start && d <= endOfDay
        }
    }

    private var totalBusinessMiles: Double {
        filteredBusinessTrips.reduce(0) { $0 + $1.totalDistanceMiles }
    }

    private var totalDeductionUSD: Double {
        filteredBusinessTrips.reduce(0) { $0 + $1.taxDeductionValueUSD }
    }

    private var totalDrivesCount: Int {
        filteredBusinessTrips.count
    }

    private var filteredPendingTrips: [TripEntity] {
        let (start, end) = activeRange
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end
        return allTrips.filter {
            guard ($0.tripClassification == .unclassified || $0.needsReview), let d = $0.startDate else { return false }
            return d >= start && d <= endOfDay
        }
    }

    private var pendingTripCount: Int {
        filteredPendingTrips.count
    }

    private var pendingDeduction: Double {
        filteredPendingTrips.reduce(0) { $0 + $1.taxDeductionValueUSD }
    }

    private var currentQuarterSummary: (miles: Double, deduction: Double, status: QuarterStatus, count: Int) {
        CoreDataManager.shared.quarterSummary(for: .q3, year: activeYear)
    }

    private var q1Summary: (miles: Double, deduction: Double, status: QuarterStatus, count: Int) {
        CoreDataManager.shared.quarterSummary(for: .q1, year: activeYear)
    }
    private var q2Summary: (miles: Double, deduction: Double, status: QuarterStatus, count: Int) {
        CoreDataManager.shared.quarterSummary(for: .q2, year: activeYear)
    }

    private var velocityPacingRatio: Double {
        let targetPerQuarter = 1978.0
        return min(1.0, max(0.1, currentQuarterSummary.deduction / targetPerQuarter))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background Scene with Alpine Scenic Wallpaper extending to top of screen
                backgroundScene

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Security & Filter Selector Bar
                        statusBadgesRow

                        // YTD Certified Write-Off Hero Card
                        ytdCertifiedHeroCard

                        // Schedule C Quarterly Accrual Section
                        scheduleCSection

                        // 1-Tap CPA Certified Export Section
                        cpaExportSection

                        // Zero Cloud Telemetry Guarantee Card
                        privacyGuaranteeCard

                        Spacer(minLength: 130)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, Device.topSafeArea + 58)
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .navigationBarHidden(true)
            .sheet(item: $exportURL) { url in
                ShareSheet(activityItems: [url])
            }
            .sheet(isPresented: $showCustomDateSheet) {
                customDatePickerSheet
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $selectedVaultTrip) { trip in
            TripDetailSheetView(trip: trip)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showExportHub) {
            ExportHubView(initialStart: activeRange.start, initialEnd: activeRange.end)
                .presentationDetents([.large])
        }
    }

    // MARK: - Custom Date Picker Sheet

    private var customDatePickerSheet: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#06090E").ignoresSafeArea()

                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Color(hex: "#00E5FF"))
                        Text("Custom Date Range")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Filter trips for export and stats")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.top, 24)

                    // Quick Presets row
                    VStack(alignment: .leading, spacing: 10) {
                        Text("QUICK PRESETS")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Color(hex: "#00E5FF").opacity(0.7))

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach([VaultFilterPreset.lastWeek, .lastMonth, .last6Months, .lastYear, .thisTaxYear]) { preset in
                                    Button {
                                        let range = preset.dateRange()
                                        customStart = range.start
                                        customEnd   = range.end
                                    } label: {
                                        Text(preset.rawValue)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(Color(hex: "#00E5FF"))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 7)
                                            .background(Color(hex: "#00E5FF").opacity(0.1))
                                            .clipShape(Capsule())
                                            .overlay(Capsule().strokeBorder(Color(hex: "#00E5FF").opacity(0.35), lineWidth: 1))
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    // Date Pickers
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("START")
                                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.4))
                                DatePicker("", selection: $customStart, displayedComponents: .date)
                                    .labelsHidden()
                                    .colorScheme(.dark)
                                    .tint(Color(hex: "#00FF88"))
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                Text("END")
                                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.4))
                                DatePicker("", selection: $customEnd, displayedComponents: .date)
                                    .labelsHidden()
                                    .colorScheme(.dark)
                                    .tint(Color(hex: "#00FF88"))
                            }
                        }
                        .padding(20)
                        .background(Color(hex: "#0A1018"))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                    }
                    .padding(.horizontal, 20)

                    // Preview count
                    let previewCount = allTrips.filter {
                        guard $0.tripClassification == .business, let d = $0.startDate else { return false }
                        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: customEnd) ?? customEnd
                        return d >= customStart && d <= endOfDay
                    }.count

                    Text("\(previewCount) business trip\(previewCount == 1 ? "" : "s") in range")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color(hex: "#00FF88"))
                        .padding(.top, 4)

                    Spacer()

                    // Apply button
                    Button {
                        selectedFilter = .custom
                        showCustomDateSheet = false
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Apply Filter")
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(hex: "#041B12"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(colors: [Color(hex: "#00FF88"), Color(hex: "#00D670")],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color(hex: "#00FF88").opacity(0.4), radius: 12, y: 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - Background Scene

    private var backgroundScene: some View {
        ZStack(alignment: .top) {
            Color(hex: "#06090E").ignoresSafeArea()

            // Mountain scenic wallpaper at top fading into deep obsidian
            Image("radar_bg_mountain")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color(hex: "#06090E").opacity(0.15),
                            Color(hex: "#06090E").opacity(0.85),
                            Color(hex: "#06090E")
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Top ambient teal aurora glow
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

    // MARK: - Status Badges Row (with Rich Filter Menu)

    private var statusBadgesRow: some View {
        HStack {
            // Left: 100% On-Device SQLite + Waveform
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: "#00FF88"))
                    .frame(width: 6, height: 6)
                    .shadow(color: Color(hex: "#00FF88"), radius: 3)

                Text("100% ON-DEVICE SQLITE")
                    .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color(hex: "#00FF88"))
                    .tracking(0.6)

                Image(systemName: "waveform.path")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(hex: "#00FF88").opacity(0.8))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color(hex: "#061A13").opacity(0.9))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color(hex: "#00FF88").opacity(0.3), lineWidth: 1))

            Spacer()

            // Right: Rich Filter Menu
            Menu {
                ForEach(VaultFilterPreset.allCases) { preset in
                    if preset == .custom {
                        Button {
                            showCustomDateSheet = true
                        } label: {
                            Label(preset.rawValue, systemImage: preset.icon)
                        }
                    } else {
                        Button {
                            selectedFilter = preset
                        } label: {
                            Label {
                                Text(preset.rawValue)
                            } icon: {
                                Image(systemName: selectedFilter == preset ? "checkmark" : preset.icon)
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: selectedFilter.icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(hex: "#00E5FF"))

                    Text(filterLabel)
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(Color(hex: "#0C141E").opacity(0.85))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
            }
        }
    }

    // MARK: - Card Background with Precise Trailing Alignment
    struct VaultCardBackground: View {
        let imageName: String
        let aspectRatio: Double
        var trailingOffset: CGFloat = 0

        var body: some View {
            GeometryReader { geo in
                ZStack(alignment: .trailing) {
                    // Background artwork image pinned to trailing edge so right-side subject is 100% visible
                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(
                            width: max(geo.size.width, geo.size.height * aspectRatio),
                            height: geo.size.height,
                            alignment: .trailing
                        )
                        .offset(x: trailingOffset)
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .trailing)
                        .clipped()

                    // Protective obsidian glass gradient on left for crystal clear readability
                    LinearGradient(
                        stops: [
                            .init(color: Color(hex: "#060B14"), location: 0.0),
                            .init(color: Color(hex: "#060B14").opacity(0.96), location: 0.45),
                            .init(color: Color(hex: "#060B14").opacity(0.70), location: 0.58),
                            .init(color: Color.clear, location: 0.78)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
            }
        }
    }

    // MARK: - YTD Certified Write-Off Hero Card (vault_hero_bg)

    private var ytdCertifiedHeroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top Row: Title + IRS § 162 Compliant Badge
            HStack(alignment: .top) {
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color(hex: "#00FF88"))

                    Text("Tax Deduction Vault")
                        .font(.system(size: 16.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Spacer()

                // IRS § 162 Compliant Badge
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(hex: "#00FF88"))

                    VStack(alignment: .leading, spacing: 0) {
                        Text("IRS § 162")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(Color(hex: "#00FF88"))
                        Text("COMPLIANT")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(Color(hex: "#00FF88"))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: "#051D14").opacity(0.9))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color(hex: "#00FF88").opacity(0.35), lineWidth: 1))
            }

            // YTD Header Tag
            HStack(spacing: 5) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(hex: "#00E5FF"))

                Text("YTD CERTIFIED WRITE-OFF")
                    .font(.system(size: 9.5, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.65))
                    .tracking(0.6)
            }

            // Big Hero Amount
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(currencySymbol)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#00FF88"), Color(hex: "#00E5FF")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: Color(hex: "#00FF88").opacity(0.35), radius: 8)

                Text(String(format: "%.2f", totalDeductionUSD))
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#00FF88"), Color(hex: "#00E5FF")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }

            // Eligible Miles & IRS Rate
            HStack(spacing: 6) {
                Image(systemName: "location.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: "#00FF88"))

                Text(String(format: "%.1f", totalBusinessMiles) + "  Total Eligible Miles")
                    .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text(String(format: "@ %.3f%@/%@", irsRate, currencySymbol, distanceUnit))
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color(hex: "#00E5FF"))
            }

            // Pending review banner — surfaces unclassified trips so the vault
            // is never silently $0.00 when a drive has been recorded.
            if pendingTripCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(hex: "#FFB020"))
                    Text("\(pendingTripCount) PENDING DRIVES • \(currencySymbol)\(String(format: "%.2f", pendingDeduction)) UNCLAIMED")
                        .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: "#FFB020"))
                    Spacer()
                }
                .padding(8)
                .background(Color(hex: "#FFB020").opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(hex: "#FFB020").opacity(0.3), lineWidth: 1))
            }

            // 3-Column Stats Sub-box
            HStack(spacing: 8) {
                // Audit Risk
                HStack(spacing: 6) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "#00FF88"))

                    VStack(alignment: .leading, spacing: 1) {
                        Text("AUDIT RISK")
                            .font(.system(size: 7.5, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.45))
                        Text("0.00%")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(Color(hex: "#00FF88"))
                        Text("LOW")
                            .font(.system(size: 7, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Color(hex: "#00FF88").opacity(0.8))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color(hex: "#07121C").opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                // IRS Rate Tier
                HStack(spacing: 6) {
                    Image(systemName: "circle.grid.cross.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "#00FF88"))

                    VStack(alignment: .leading, spacing: 1) {
                        Text("IRS RATE TIER")
                            .font(.system(size: 7.5, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.45))
                        Text("Standard • '26")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color(hex: "#07121C").opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                // Logged Trips
                HStack(spacing: 6) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "#00E5FF"))

                    VStack(alignment: .leading, spacing: 1) {
                        Text("LOGGED TRIPS")
                            .font(.system(size: 7.5, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.45))
                        Text("\(totalDrivesCount) Drives")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(Color(hex: "#00E5FF"))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color(hex: "#07121C").opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VaultCardBackground(imageName: "vault_hero_bg", aspectRatio: 1024.0 / 377.0))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color(hex: "#00FF88").opacity(0.45), Color(hex: "#00E5FF").opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: Color.black.opacity(0.55), radius: 16, x: 0, y: 8)
    }

    // MARK: - Schedule C Quarterly Accrual Section

    private var scheduleCSection: some View {
        VStack(spacing: 12) {
            // Section Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(hex: "#00FF88"))

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Schedule C Quarterly")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Accrual")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }

                Spacer()

                HStack(spacing: 5) {
                    Text("Form 1040 Auto-Sync")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))

                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(hex: "#00FF88"))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(hex: "#0B1520").opacity(0.85))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
            }

            // Dynamic Quarter Accrual Rows
            VStack(spacing: 8) {
                // Q1 Row
                quarterAccrualRow(
                    isLocked: true,
                    quarter: "Q1 • Jan-Mar",
                    badgeText: q1Summary.count > 0 ? "AUDITED" : "NO DATA",
                    badgeColor: q1Summary.count > 0 ? Color(hex: "#00FF88") : Color(hex: "#00E5FF"),
                    milesText: q1Summary.miles > 0 ? String(format: "%.1f business %@", MileageUnits.distanceValue(q1Summary.miles), MileageUnits.unitLabel) : "— no trips",
                    amountText: q1Summary.deduction > 0 ? String(format: "$%.2f", q1Summary.deduction) : "$0.00",
                    subText: "Closed & Signed",
                    isActive: false
                )

                // Q2 Row
                quarterAccrualRow(
                    isLocked: true,
                    quarter: "Q2 • Apr-Jun",
                    badgeText: q2Summary.count > 0 ? "AUDITED" : "NO DATA",
                    badgeColor: q2Summary.count > 0 ? Color(hex: "#00FF88") : Color(hex: "#00E5FF"),
                    milesText: q2Summary.miles > 0 ? String(format: "%.1f business %@", MileageUnits.distanceValue(q2Summary.miles), MileageUnits.unitLabel) : "— no trips",
                    amountText: q2Summary.deduction > 0 ? String(format: "$%.2f", q2Summary.deduction) : "$0.00",
                    subText: "Closed & Signed",
                    isActive: false
                )

                // Q3 Row (Active Accumulation)
                quarterAccrualRow(
                    isLocked: false,
                    quarter: "Q3 • Jul-Sep",
                    badgeText: "ACTIVE",
                    badgeColor: Color(hex: "#00E5FF"),
                    milesText: currentQuarterSummary.miles > 0 ? String(format: "%.1f business %@", MileageUnits.distanceValue(currentQuarterSummary.miles), MileageUnits.unitLabel) : "— no trips yet",
                    amountText: currentQuarterSummary.deduction > 0 ? String(format: "$%.2f", currentQuarterSummary.deduction) : "$0.00",
                    subText: "Live Accumulation",
                    isActive: true
                )
            }

            // Quarter Velocity Progress Bar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Quarter Velocity: ")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                    + Text(velocityPacingRatio >= 0.8 ? "On Track" : velocityPacingRatio >= 0.5 ? "Building" : "Getting Started")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(Color(hex: "#00E5FF"))

                    Spacer()

                    Text(String(format: "%.0f%% of Target", velocityPacingRatio * 100))
                        .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Color(hex: "#00E5FF"))
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#00E5FF"), Color(hex: "#00FF88")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * 0.82)
                    }
                }
                .frame(height: 6)
            }
            .padding(.top, 4)
        }
        .padding(14)
        .background(Color(hex: "#0A1018").opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 6)
    }

    private func quarterAccrualRow(
        isLocked: Bool,
        quarter: String,
        badgeText: String,
        badgeColor: Color,
        milesText: String,
        amountText: String,
        subText: String,
        isActive: Bool) -> some View {

        HStack {
            // Left Icon + Quarter Info
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isActive ? Color(hex: "#09242E") : Color(hex: "#0B1D22"))
                        .frame(width: 36, height: 36)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(isActive ? Color(hex: "#00E5FF").opacity(0.4) : Color(hex: "#00FF88").opacity(0.3), lineWidth: 1)
                        )

                    Image(systemName: isLocked ? "lock.fill" : "clock.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(isActive ? Color(hex: "#00E5FF") : Color(hex: "#00FF88"))
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(quarter)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)

                        Text(badgeText)
                            .font(.system(size: 7.5, weight: .heavy, design: .monospaced))
                            .foregroundStyle(badgeColor)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(badgeColor.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    Text(milesText)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            Spacer()

            // Right: Amount & Status
            HStack(spacing: 8) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(amountText)
                        .font(.system(size: 14.5, weight: .black, design: .rounded))
                        .foregroundStyle(isActive ? Color(hex: "#00E5FF") : .white)

                    Text(subText)
                        .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: "#00E5FF").opacity(0.6))
            }
        }
        .padding(10)
        .background(Color(hex: "#080F17").opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
    }

    // MARK: - 1-Tap CPA Certified Export Section

    private var cpaExportSection: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Text("1-Tap CPA Certified Export")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(hex: "#00FF88"))
                    Text("Tamper-Proof Hash")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "#00FF88"))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: "#072018").opacity(0.9))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color(hex: "#00FF88").opacity(0.35), lineWidth: 1))
            }

            // Card 1: IRS Certified Log (PDF)
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#061A14").opacity(0.8))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color(hex: "#00FF88").opacity(0.5), lineWidth: 1.5)
                            )

                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color(hex: "#00FF88"))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("IRS Certified Log")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)

                            Text("PDF")
                                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }

                        Text("Complete forensic ledger with timestamps, start/stop odometer values, business purposes, and IRS Section 274(d) compliant CPA signature affidavit.")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineSpacing(2)
                            .frame(maxWidth: 195, alignment: .leading)
                    }
                }

                HStack(alignment: .center) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil.and.outline")
                            .font(.system(size: 10))
                            .foregroundStyle(Color(hex: "#00FF88"))
                        Text("Includes Form 4562 • Line 44")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    Spacer()

                    // Export PDF Button (Bright Glowing Neon Emerald, Clear and High Contrast)
                    Button {
                        showExportHub = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.system(size: 13, weight: .black))

                            Text("Export PDF")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                        }
                        .foregroundStyle(Color(hex: "#041B12"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#00FF88"), Color(hex: "#00D670")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: Color(hex: "#00FF88").opacity(0.55), radius: 10, x: 0, y: 3)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(VaultCardBackground(imageName: "vault_export_pdf_bg", aspectRatio: 1024.0 / 377.0))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color(hex: "#00FF88").opacity(0.4), Color(hex: "#00E5FF").opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .shadow(color: Color.black.opacity(0.45), radius: 12, x: 0, y: 6)

            // Card 2: Tax Spreadsheet (CSV)
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#061520").opacity(0.8))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color(hex: "#00E5FF").opacity(0.5), lineWidth: 1.5)
                            )

                        Image(systemName: "tablecells.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color(hex: "#00E5FF"))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("Tax Spreadsheet")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)

                            Text("CSV")
                                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }

                        Text("Mapped 1:1 for TurboTax Business, QuickBooks Online, Xero, and Thomson Reuters UltraTax with client classification tags and expense codes.")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineSpacing(2)
                            .frame(maxWidth: 195, alignment: .leading)
                    }
                }

                HStack(alignment: .center) {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.2.square")
                            .font(.system(size: 10))
                            .foregroundStyle(Color(hex: "#00E5FF"))
                        Text("Pre-formatted columns (UTF-8)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    Spacer()

                    // Export CSV Button (Bright Glowing Electric Cyan, Clear and High Contrast)
                    Button {
                        exportURL = ExportEngine.exportCSV(trips: filteredBusinessTrips)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.system(size: 13, weight: .black))

                            Text("Export CSV")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                        }
                        .foregroundStyle(Color(hex: "#041620"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#00E5FF"), Color(hex: "#00B8D4")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: Color(hex: "#00E5FF").opacity(0.55), radius: 10, x: 0, y: 3)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(VaultCardBackground(imageName: "vault_export_csv_bg", aspectRatio: 1024.0 / 344.0))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color(hex: "#00E5FF").opacity(0.4), Color(hex: "#00FF88").opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .shadow(color: Color.black.opacity(0.45), radius: 12, x: 0, y: 6)
        }
    }

    // MARK: - Privacy Guarantee Card (vault_privacy_shield_bg)

    private var privacyGuaranteeCard: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#061520").opacity(0.8))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle()
                            .strokeBorder(Color(hex: "#00E5FF").opacity(0.5), lineWidth: 1.5)
                    )

                Image(systemName: "lock.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(hex: "#00E5FF"))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text("ZERO CLOUD TELEMETRY GUARANTEE")
                        .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white)

                    Circle()
                        .fill(Color(hex: "#00FF88"))
                        .frame(width: 5, height: 5)
                }

                Text("Your high-fidelity GPS breadcrumbs, stop durations, and visited addresses stay encrypted locally in an AES-256 SQLite partition on your iPhone. Never synced to remote servers, never monetized, and never disclosed to insurance brokers.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineSpacing(2)
                    .frame(maxWidth: 200, alignment: .leading)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VaultCardBackground(imageName: "vault_privacy_shield_bg", aspectRatio: 1024.0 / 341.0))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 6)
    }
}

// MARK: - ShareSheet Helper

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
