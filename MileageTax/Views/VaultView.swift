// VaultView.swift — MileageTax · Tab 4: Vault (Schedule C / Export)
// IRS-grade mileage log with period filter, CSV/PDF export, and Schedule C summary.

import SwiftUI
import CoreData

struct VaultView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TripEntity.startDate, ascending: false)],
        predicate: NSPredicate(format: "isInProgress == false"),
        animation: .default)
    private var allTrips: FetchedResults<TripEntity>

    @State private var period: VaultPeriod = .ytd
    @State private var exportType: ExportType? = nil
    @State private var showExportShare = false
    @State private var exportURL: URL? = nil

    enum VaultPeriod: String, CaseIterable {
        case ytd = "YTD"
        case q1 = "Q1"
        case q2 = "Q2"
        case q3 = "Q3"
        case q4 = "Q4"
        case custom = "Custom"
    }

    enum ExportType: String, Identifiable {
        case csv = "CSV"
        case pdf = "PDF"
        var id: String { rawValue }
    }

    private var filteredTrips: [TripEntity] {
        let now = Date()
        let calendar = Calendar.current
        let year = calendar.component(.year, from: now)
        let trips = allTrips.filter { $0.classification == "business" }
        switch period {
        case .ytd:
            let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? now
            return trips.filter { ($0.startDate ?? .distantPast) >= start }
        case .q1:
            let range = quarterRange(year: year, quarter: 1)
            return trips.filter { inRange($0, range) }
        case .q2:
            let range = quarterRange(year: year, quarter: 2)
            return trips.filter { inRange($0, range) }
        case .q3:
            let range = quarterRange(year: year, quarter: 3)
            return trips.filter { inRange($0, range) }
        case .q4:
            let range = quarterRange(year: year, quarter: 4)
            return trips.filter { inRange($0, range) }
        case .custom:
            return trips.map { $0 }
        }
    }

    private var totalMiles:     Double { filteredTrips.reduce(0) { $0 + $1.totalDistanceMiles } }
    private var totalDeduction: Double { filteredTrips.reduce(0) { $0 + $1.taxDeductionValueUSD } }

    var body: some View {
        ZStack {
            backgroundLayer
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {
                    headerSection
                    scheduleCCard
                    periodFilterRow
                    exportButtons
                    tripLogTable
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)
            }
        }
        .sheet(item: $exportType) { type in
            ExportShareSheet(type: type, trips: filteredTrips)
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            Color.obsidian.ignoresSafeArea()
            RadialGradient(
                colors: [Color.amberGlow.opacity(0.05), .clear],
                center: .topTrailing, startRadius: 0, endRadius: 280)
            .ignoresSafeArea()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Vault")
                    .font(.displayMedium)
                    .foregroundStyle(Color.textPrimary)
                Text("IRS-Grade Mileage Log")
                    .font(.captionText)
                    .foregroundStyle(Color.amberGlow)
            }
            Spacer()
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 28))
                .foregroundStyle(AppGradient.goldGradient)
        }
        .padding(.top, 8)
    }

    // MARK: - Schedule C Summary Card

    private var scheduleCCard: some View {
        VStack(spacing: AppSpacing.md) {
            HStack {
                Label("Schedule C Summary", systemImage: "doc.text.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.amberGlow)
                Spacer()
                Text(period.rawValue)
                    .font(.captionText)
                    .foregroundStyle(Color.textSecondary)
            }

            HStack(spacing: 0) {
                summaryCell(
                    title: "Total Miles",
                    value: String(format: "%.1f", totalMiles),
                    sub: "business miles",
                    color: .neonEmerald)
                Divider().background(Color.glassBorder)
                summaryCell(
                    title: "IRS Deduction",
                    value: String(format: "$%.2f", totalDeduction),
                    sub: "@$0.67/mi",
                    color: .amberGlow)
                Divider().background(Color.glassBorder)
                summaryCell(
                    title: "Trips",
                    value: "\(filteredTrips.count)",
                    sub: "logged",
                    color: .electricCyan)
            }

            // Projected annual
            let projected = totalDeduction * (12.0 / max(Double(currentMonth), 1))
            HStack {
                Image(systemName: "arrow.up.right.circle.fill")
                    .foregroundStyle(Color.neonEmerald)
                Text(String(format: "Projected annual deduction: $%.0f", projected))
                    .font(.captionText)
                    .foregroundStyle(Color.textSecondary)
                Spacer()
            }
        }
        .padding(AppSpacing.md)
        .glassCard(radius: AppRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .strokeBorder(Color.amberGlow.opacity(0.2), lineWidth: 1))
    }

    private func summaryCell(title: String, value: String, sub: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.micro)
                .foregroundStyle(Color.textTertiary)
            Text(value)
                .font(.displayMedium)
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(sub)
                .font(.micro)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.sm)
    }

    // MARK: - Period Filter

    private var periodFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(VaultPeriod.allCases, id: \.self) { p in
                    Button {
                        withAnimation { period = p }
                    } label: {
                        Text(p.rawValue)
                            .font(.captionText)
                            .foregroundStyle(period == p ? Color.textOnAccent : Color.textSecondary)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(period == p ? Color.neonEmerald : Color.white.opacity(0.06))
                            )
                    }
                }
            }
        }
    }

    // MARK: - Export Buttons

    private var exportButtons: some View {
        HStack(spacing: AppSpacing.sm) {
            Button {
                exportType = .csv
            } label: {
                Label("Export CSV", systemImage: "tablecells")
                    .font(.subheadline)
                    .foregroundStyle(Color.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppGradient.cyanEmerald)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            }
            Button {
                exportType = .pdf
            } label: {
                Label("Export PDF", systemImage: "doc.richtext")
                    .font(.subheadline)
                    .foregroundStyle(Color.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppGradient.goldGradient)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            }
        }
    }

    // MARK: - Trip Log Table

    private var tripLogTable: some View {
        VStack(spacing: 0) {
            // Table header
            HStack {
                Text("Date").font(.micro).foregroundStyle(Color.textTertiary)
                Spacer()
                Text("Route").font(.micro).foregroundStyle(Color.textTertiary)
                Spacer()
                Text("Miles").font(.micro).foregroundStyle(Color.textTertiary)
                Spacer()
                Text("Deduction").font(.micro).foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(Color.white.opacity(0.04))

            Divider().background(Color.glassBorder)

            if filteredTrips.isEmpty {
                Text("No business trips in this period")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                    .padding(AppSpacing.xxl)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(filteredTrips, id: \.objectID) { trip in
                        tripTableRow(trip)
                        Divider().background(Color.glassBorder).padding(.leading, AppSpacing.md)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                        .strokeBorder(Color.glassBorder, lineWidth: 1)))
    }

    private func tripTableRow(_ trip: TripEntity) -> some View {
        HStack(spacing: AppSpacing.sm) {
            if let date = trip.startDate {
                Text(date, format: .dateTime.month(.abbreviated).day())
                    .font(.captionText)
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 44, alignment: .leading)
            }
            Text((trip.startAddress ?? "").truncated(to: 12))
                .font(.captionText)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
            Spacer()
            Text(String(format: "%.1f", trip.totalDistanceMiles))
                .font(.captionText)
                .foregroundStyle(Color.neonEmerald)
                .frame(width: 40)
            Text(String(format: "$%.2f", trip.taxDeductionValueUSD))
                .font(.captionText)
                .foregroundStyle(Color.amberGlow)
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    private var currentMonth: Int {
        Calendar.current.component(.month, from: Date())
    }

    private func quarterRange(year: Int, quarter: Int) -> ClosedRange<Date> {
        let cal = Calendar.current
        let startMonth = (quarter - 1) * 3 + 1
        let start = cal.date(from: DateComponents(year: year, month: startMonth, day: 1)) ?? Date()
        let end = cal.date(byAdding: .month, value: 3, to: start) ?? Date()
        return start...end
    }

    private func inRange(_ trip: TripEntity, _ range: ClosedRange<Date>) -> Bool {
        guard let d = trip.startDate else { return false }
        return range.contains(d)
    }
}

// MARK: - Export Share Sheet

struct ExportShareSheet: View {
    let type: VaultView.ExportType
    let trips: [TripEntity]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.obsidian.ignoresSafeArea()
                VStack(spacing: AppSpacing.xl) {
                    Image(systemName: type == .csv ? "tablecells" : "doc.richtext")
                        .font(.system(size: 60))
                        .foregroundStyle(type == .csv
                            ? AnyShapeStyle(AppGradient.cyanEmerald)
                            : AnyShapeStyle(AppGradient.goldGradient))
                    Text("Export \(type.rawValue)")
                        .font(.displayMedium)
                        .foregroundStyle(Color.textPrimary)
                    Text("\(trips.count) business trips")
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                    Button {
                        performExport()
                    } label: {
                        Text("Share \(type.rawValue) File")
                            .font(.subheadline)
                            .foregroundStyle(Color.textOnAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppGradient.emeraldPulse)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                            .emeraldGlow()
                    }
                    .padding(.horizontal, AppSpacing.lg)
                }
                .padding(AppSpacing.xl)
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func performExport() {
        let url: URL
        if type == .csv {
            url = ExportEngine.exportCSV(trips: trips)
        } else {
            url = ExportEngine.exportPDF(trips: trips)
        }
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }
}

// MARK: - String Helper

extension String {
    func truncated(to length: Int) -> String {
        count <= length ? self : String(prefix(length)) + "…"
    }
}
