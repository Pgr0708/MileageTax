//
//  ExportHubView.swift
//  MileageTax — Phase 7: Premium Export & Reports Hub
//

import SwiftUI
import CoreData

struct ExportHubView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var moc

    @AppStorage(AppStorageKeys.currencySymbol) private var currencySymbol = "$"
    @AppStorage(AppStorageKeys.distanceUnit)   private var distanceUnit   = "mi"
    @AppStorage(AppStorageKeys.countryTaxLabel) private var countryLabel  = "IRS Standard (USA)"
    @AppStorage(AppStorageKeys.userName)       private var userName: String = "Taxpayer"

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TripEntity.startDate, ascending: false)],
        predicate: NSPredicate(format: "isInProgress == false"),
        animation: .default)
    private var allTrips: FetchedResults<TripEntity>

    enum ReportType: String, CaseIterable {
        case taxReport      = "Tax Report"
        case reimbursement  = "Reimbursement Report"
        case mileageLog     = "Detailed Mileage Log"
        case accountant     = "Accountant Package"

        var icon: String {
            switch self {
            case .taxReport:     return "doc.text.fill"
            case .reimbursement: return "banknote.fill"
            case .mileageLog:    return "list.bullet.clipboard.fill"
            case .accountant:    return "folder.fill.badge.person.crop"
            }
        }
        var color: Color {
            switch self {
            case .taxReport:     return Color(hex: "#00FF88")
            case .reimbursement: return Color(hex: "#00E5FF")
            case .mileageLog:    return Color(hex: "#A78BFA")
            case .accountant:    return Color(hex: "#F59E0B")
            }
        }
    }

    // Quick preset chips inside the date range card
    enum QuickPreset: String, CaseIterable {
        case lastWeek    = "Last Week"
        case lastMonth   = "Last Month"
        case last6M      = "Last 6 Mo"
        case lastYear    = "Last Year"
        case ytd         = "YTD"

        func dateRange() -> (start: Date, end: Date) {
            let now = Date()
            let cal = Calendar.current
            switch self {
            case .lastWeek:
                return (cal.date(byAdding: .day, value: -7, to: now) ?? now, now)
            case .lastMonth:
                return (cal.date(byAdding: .day, value: -30, to: now) ?? now, now)
            case .last6M:
                return (cal.date(byAdding: .month, value: -6, to: now) ?? now, now)
            case .lastYear:
                return (cal.date(byAdding: .year, value: -1, to: now) ?? now, now)
            case .ytd:
                let year = cal.component(.year, from: now)
                return (cal.date(from: DateComponents(year: year, month: 1, day: 1)) ?? now, now)
            }
        }
    }

    @State private var selectedType: ReportType = .taxReport
    @State private var includePersonal = false
    @State private var includeBusiness = true
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isExporting = false
    @State private var shareItem: URL? = nil
    @State private var showShareSheet = false

    // Pre-populate dates from VaultView filter
    init(initialStart: Date? = nil, initialEnd: Date? = nil) {
        let cal = Calendar.current
        let year = cal.component(.year, from: Date())
        let defaultStart = cal.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date()
        _startDate = State(initialValue: initialStart ?? defaultStart)
        _endDate   = State(initialValue: initialEnd   ?? Date())
    }

    private var filteredTrips: [TripEntity] {
        allTrips.filter { trip in
            guard let d = trip.startDate else { return false }
            let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
            let inRange = d >= startDate && d <= endOfDay
            let classOk = (includeBusiness && trip.classification == "business")
                       || (includePersonal  && trip.classification == "personal")
                       || trip.classification == "unclassified"
            return inRange && classOk
        }
    }

    private var businessTrips: [TripEntity]  { filteredTrips.filter { $0.classification == "business" } }
    private var totalMiles: Double            { businessTrips.reduce(0) { $0 + $1.totalDistanceMiles } }
    private var totalDeduction: Double        { businessTrips.reduce(0) { $0 + $1.taxDeductionValueUSD } }

    private var rangeLabelString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, yyyy"
        return "\(fmt.string(from: startDate)) – \(fmt.string(from: endDate))"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#06090E").ignoresSafeArea()

                // Subtle ambient glows
                RadialGradient(colors: [Color(hex: "#00FF88").opacity(0.06), .clear],
                               center: .topTrailing, startRadius: 0, endRadius: 300)
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        // ── Preview Hero ───────────────────────────────────
                        previewHero

                        // ── Report Type Picker ─────────────────────────────
                        reportTypePicker

                        // ── Date Range ─────────────────────────────────────
                        dateRangeCard

                        // ── Filters ────────────────────────────────────────
                        filtersCard

                        // ── Export Buttons ─────────────────────────────────
                        exportButtons

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Export & Reports")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color(hex: "#00FF88"))
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color(hex: "#06090E"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showShareSheet) {
                if let url = shareItem {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }

    // MARK: - Preview Hero

    private var previewHero: some View {
        VStack(spacing: 8) {
            // Active date range pill
            HStack(spacing: 5) {
                Image(systemName: "calendar")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(hex: "#00E5FF"))
                Text(rangeLabelString)
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color(hex: "#00E5FF"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Color(hex: "#00E5FF").opacity(0.1))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color(hex: "#00E5FF").opacity(0.3), lineWidth: 1))

            Text(countryLabel)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(Color(hex: "#00FF88"))

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(currencySymbol)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: "#00FF88"))
                Text(String(format: "%.2f", totalDeduction))
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }

            Text(String(format: "%.1f %@ • %d business trip%@",
                        totalMiles, distanceUnit, businessTrips.count,
                        businessTrips.count == 1 ? "" : "s"))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))

            if filteredTrips.isEmpty {
                Text("No trips match this filter")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: "#F59E0B"))
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            ZStack {
                Color(hex: "#061A13")
                LinearGradient(colors: [Color(hex: "#00FF88").opacity(0.08), .clear],
                               startPoint: .top, endPoint: .bottom)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color(hex: "#00FF88").opacity(0.25), lineWidth: 1))
        .animation(.easeInOut(duration: 0.2), value: totalDeduction)
    }

    // MARK: - Report Type Picker

    private var reportTypePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("REPORT TYPE")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(Color(hex: "#00FF88"))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ReportType.allCases, id: \.rawValue) { type in
                        Button {
                            selectedType = type
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: type.icon)
                                    .font(.system(size: 12, weight: .bold))
                                Text(type.rawValue)
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(selectedType == type ? Color(hex: "#06090E") : type.color)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(selectedType == type ? type.color : type.color.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(selectedType == type ? .clear : type.color.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .animation(.easeInOut(duration: 0.15), value: selectedType)
                    }
                }
            }
        }
    }

    // MARK: - Date Range Card

    private var dateRangeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DATE RANGE")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(Color(hex: "#00E5FF"))

            // Quick preset chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(QuickPreset.allCases, id: \.rawValue) { preset in
                        Button {
                            let range = preset.dateRange()
                            withAnimation(.easeInOut(duration: 0.2)) {
                                startDate = range.start
                                endDate   = range.end
                            }
                        } label: {
                            Text(preset.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color(hex: "#00E5FF"))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(hex: "#00E5FF").opacity(0.1))
                                .clipShape(Capsule())
                                .overlay(Capsule().strokeBorder(Color(hex: "#00E5FF").opacity(0.3), lineWidth: 1))
                        }
                    }
                }
            }

            // Manual date pickers
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "#00FF88"))
                    Text("Start")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                        .colorScheme(.dark)
                        .tint(Color(hex: "#00FF88"))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider().background(Color.white.opacity(0.08))

                HStack {
                    Image(systemName: "calendar.badge.minus")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "#00E5FF"))
                    Text("End")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    DatePicker("", selection: $endDate, displayedComponents: .date)
                        .labelsHidden()
                        .colorScheme(.dark)
                        .tint(Color(hex: "#00E5FF"))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(hex: "#0A1018"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.07), lineWidth: 1))
        }
    }

    // MARK: - Filters Card

    private var filtersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("INCLUDE TRIPS")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(Color(hex: "#A78BFA"))

            VStack(spacing: 8) {
                filterRow(label: "Business Trips", color: Color(hex: "#00FF88"), binding: $includeBusiness)
                filterRow(label: "Personal Trips",  color: Color(hex: "#00E5FF"), binding: $includePersonal)
            }
            .padding(16)
            .background(Color(hex: "#0A1018"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.07), lineWidth: 1))
        }
    }

    private func filterRow(label: String, color: Color, binding: Binding<Bool>) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
            Spacer()
            Toggle("", isOn: binding).tint(color)
        }
    }

    // MARK: - Export Buttons

    private var exportButtons: some View {
        VStack(spacing: 12) {
            // PDF Export
            Button {
                doExport(format: "pdf")
            } label: {
                HStack {
                    if isExporting {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(Color(hex: "#041B12"))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "doc.richtext.fill")
                        Text("Export PDF Report")
                    }
                    Spacer()
                    Text("\(filteredTrips.count) trips")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .opacity(0.7)
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(hex: "#041B12"))
                .padding(16)
                .background(Color(hex: "#00FF88"))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color(hex: "#00FF88").opacity(0.3), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(isExporting || filteredTrips.isEmpty)
            .opacity(filteredTrips.isEmpty ? 0.5 : 1.0)

            // CSV Export
            Button {
                doExport(format: "csv")
            } label: {
                HStack {
                    Image(systemName: "tablecells.fill")
                    Text("Export CSV (20 fields)")
                    Spacer()
                    Text("\(filteredTrips.count) trips")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .opacity(0.7)
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(hex: "#00E5FF"))
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(Color(hex: "#00E5FF").opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(hex: "#00E5FF").opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(isExporting || filteredTrips.isEmpty)
            .opacity(filteredTrips.isEmpty ? 0.5 : 1.0)

            if filteredTrips.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color(hex: "#F59E0B"))
                    Text("No trips found for this date range and filter")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Export Action

    private func doExport(format: String) {
        isExporting = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        DispatchQueue.global(qos: .userInitiated).async {
            let url: URL
            if format == "pdf" {
                url = ExportEngine.exportPDF(trips: filteredTrips, userName: userName,
                                             startDate: startDate, endDate: endDate)
            } else {
                url = ExportEngine.exportCSV(trips: filteredTrips)
            }
            DispatchQueue.main.async {
                isExporting = false
                shareItem = url
                showShareSheet = true
            }
        }
    }
}
