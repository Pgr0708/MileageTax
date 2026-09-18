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

    @State private var selectedType: ReportType = .taxReport
    @State private var includePersonal = false
    @State private var includeBusiness = true
    @State private var startDate = Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: 1, day: 1)) ?? Date()
    @State private var endDate   = Date()
    @State private var isExporting = false
    @State private var shareItem: URL? = nil
    @State private var showShareSheet = false

    private var filteredTrips: [TripEntity] {
        allTrips.filter { trip in
            guard let d = trip.startDate else { return false }
            let inRange = d >= startDate && d <= endDate
            let classOk = (includeBusiness && trip.classification == "business")
                       || (includePersonal && trip.classification == "personal")
                       || trip.classification == "unclassified"
            return inRange && classOk
        }
    }

    private var businessTrips: [TripEntity] { filteredTrips.filter { $0.classification == "business" } }
    private var totalMiles: Double { businessTrips.reduce(0) { $0 + $1.totalDistanceMiles } }
    private var totalDeduction: Double { businessTrips.reduce(0) { $0 + $1.taxDeductionValueUSD } }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#06090E").ignoresSafeArea()

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

            Text(String(format: "%.1f %@ • %d business trips", totalMiles, distanceUnit, businessTrips.count))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
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
    }

    // MARK: - Report Type Picker

    private var reportTypePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("REPORT TYPE")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(Color(hex: "#00FF88"))

            VStack(spacing: 8) {
                ForEach(ReportType.allCases, id: \.self) { type in
                    Button { selectedType = type } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(type.color.opacity(0.15))
                                    .frame(width: 38, height: 38)
                                Image(systemName: type.icon)
                                    .font(.system(size: 16))
                                    .foregroundStyle(type.color)
                            }
                            Text(type.rawValue)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                            Spacer()
                            if selectedType == type {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(type.color)
                            }
                        }
                        .padding(14)
                        .background(
                            selectedType == type
                                ? type.color.opacity(0.08)
                                : Color(hex: "#0A1018").opacity(0.9)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(
                                    selectedType == type ? type.color.opacity(0.4) : Color.white.opacity(0.06),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
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

            VStack(spacing: 12) {
                DatePicker("Start", selection: $startDate, displayedComponents: .date)
                    .colorScheme(.dark).tint(Color(hex: "#00FF88"))
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                Divider().background(Color.white.opacity(0.08))
                DatePicker("End", selection: $endDate, displayedComponents: .date)
                    .colorScheme(.dark).tint(Color(hex: "#00FF88"))
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
            }
            .padding(16)
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
                filterRow(label: "Personal Trips", color: Color(hex: "#00E5FF"), binding: $includePersonal)
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
            Button { doExport(format: "pdf") } label: {
                HStack {
                    Image(systemName: "doc.richtext.fill")
                    Text("Generate PDF")
                    Spacer()
                    if isExporting { ProgressView().tint(.black) }
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(hex: "#061A13"))
                .padding(16)
                .background(Color(hex: "#00FF88"))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color(hex: "#00FF88").opacity(0.3), radius: 10, y: 4)
            }
            .buttonStyle(.plain)

            Button { doExport(format: "csv") } label: {
                HStack {
                    Image(systemName: "tablecells.fill")
                    Text("Export CSV (20 fields)")
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
        }
    }

    // MARK: - Export Action

    private func doExport(format: String) {
        isExporting = true
        DispatchQueue.global(qos: .userInitiated).async {
            let url: URL
            if format == "pdf" {
                url = ExportEngine.exportPDF(trips: filteredTrips, userName: userName)
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

