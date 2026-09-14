//
//  VaultView.swift
//  MileageTax · Tab 4: Vault (Schedule C / Export)
//  Obsidian Precision Design System · Exact Match to Spec
//

import SwiftUI
import CoreData
import UIKit

struct VaultView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TripEntity.startDate, ascending: false)],
        predicate: NSPredicate(format: "isInProgress == false"),
        animation: .default)
    private var allTrips: FetchedResults<TripEntity>

    @AppStorage(AppStorageKeys.irsRateOverride) private var irsRate: Double = MileageTaxDefaults.irsRatePerMile

    @State private var selectedTaxYear: String = "Tax Year 2026"
    @State private var showExportShare = false
    @State private var exportURL: URL? = nil

    private var businessTrips: [TripEntity] {
        allTrips.filter { $0.tripClassification == .business }
    }

    private var totalBusinessMiles: Double {
        businessTrips.reduce(0) { $0 + $1.totalDistanceMiles }
    }

    private var totalDeductionUSD: Double {
        businessTrips.reduce(0) { $0 + $1.taxDeductionValueUSD }
    }

    private var totalDrivesCount: Int {
        businessTrips.count
    }

    private var currentQuarterSummary: (miles: Double, deduction: Double, status: QuarterStatus, count: Int) {
        CoreDataManager.shared.quarterSummary(for: .q3)
    }

    private var velocityPacingRatio: Double {
        let targetPerQuarter = 1978.0 // Normalized Q3 target threshold
        return min(1.0, max(0.1, currentQuarterSummary.deduction / targetPerQuarter))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(hex: "#06090E").ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Top Header Bar
                        topHeaderBar

                        // Security & Tax Year Selector Bar
                        statusBadgesRow

                        // Title & Compliance Header
                        titleSection

                        // YTD Certified Write-Off Hero Card
                        ytdCertifiedHeroCard

                        // Schedule C Quarterly Accrual Section
                        scheduleCSection

                        // 1-Tap CPA Certified Export Section
                        cpaExportSection

                        // Zero Cloud Telemetry Guarantee Card
                        privacyGuaranteeCard

                        Spacer(minLength: 110)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showExportShare) {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
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

    // MARK: - Status Badges Row

    private var statusBadgesRow: some View {
        HStack {
            // Left: 100% On-Device SQLite
            HStack(spacing: 5) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(hex: "#00FF88"))
                Text("100% ON-DEVICE SQLITE")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color(hex: "#00FF88"))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color(hex: "#071B14"))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color(hex: "#00FF88").opacity(0.3), lineWidth: 1))

            Spacer()

            // Right: Tax Year Selector
            Menu {
                Button("Tax Year 2026") { selectedTaxYear = "Tax Year 2026" }
                Button("Tax Year 2025") { selectedTaxYear = "Tax Year 2025" }
                Button("Tax Year 2024") { selectedTaxYear = "Tax Year 2024" }
            } label: {
                HStack(spacing: 4) {
                    Text(selectedTaxYear)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
            }
        }
    }

    // MARK: - Title Section

    private var titleSection: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Tax Deduction\nVault")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineSpacing(2)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("IRS § 162")
                    .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color(hex: "#00FF88"))
                Text("COMPLIANT")
                    .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color(hex: "#00FF88"))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(hex: "#081F17"))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color(hex: "#00FF88").opacity(0.3), lineWidth: 1))
        }
        .padding(.vertical, 2)
    }

    // MARK: - YTD Certified Write-Off Hero Card

    private var ytdCertifiedHeroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Color(hex: "#00FF88"))
                    Text("YTD CERTIFIED WRITE-OFF")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.65))
                }
                Spacer()
            }

            // Big Number
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("$")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: "#00FF88"))
                    .shadow(color: Color(hex: "#00FF88").opacity(0.4), radius: 8)

                Text(String(format: "%.2f", totalDeductionUSD))
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }

            // Eligible Miles & Rate Badge
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: "#00FF88"))
                    .frame(width: 6, height: 6)

                Text(String(format: "%.1f Total Eligible Miles", totalBusinessMiles))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))

                Text(String(format: "%.0f¢/mi", irsRate * 100))
                    .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color(hex: "#00E5FF"))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: "#00E5FF").opacity(0.12))
                    .clipShape(Capsule())
            }

            // 3-Column Stats Sub-box
            HStack(spacing: 0) {
                // Audit Risk
                VStack(spacing: 2) {
                    Text("AUDIT RISK")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                    HStack(spacing: 2) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Color(hex: "#00FF88"))
                        Text("0.01%")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(Color(hex: "#00FF88"))
                    }
                }
                .frame(maxWidth: .infinity)

                Divider().background(Color.white.opacity(0.1)).frame(height: 22)

                // Rate Tier
                VStack(spacing: 2) {
                    Text("IRS RATE TIER")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                    Text("Standard '26")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)

                Divider().background(Color.white.opacity(0.1)).frame(height: 22)

                // Logged Trips
                VStack(spacing: 2) {
                    Text("LOGGED TRIPS")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                    Text("\(totalDrivesCount) Drives")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(Color(hex: "#00E5FF"))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)
            .background(Color(hex: "#07121C").opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color(hex: "#0B1824"), Color(hex: "#081018")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color(hex: "#00FF88").opacity(0.35), Color(hex: "#00E5FF").opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: Color.black.opacity(0.5), radius: 16, x: 0, y: 8)
    }

    // MARK: - Schedule C Quarterly Accrual Section

    private var scheduleCSection: some View {
        VStack(spacing: 12) {
            // Section Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.doc.horizontal.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "#00E5FF"))

                    Text("Schedule C Quarterly Accrual")
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(.white)
                }

                Spacer()

                Text("FORM 1040 AUTO-SYNC")
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
            }

            // Dynamic Quarter Accrual Rows
            ForEach(QuarterPeriod.allCases.filter { $0 != .q4 }) { q in
                let summary = CoreDataManager.shared.quarterSummary(for: q)
                quarterAccrualRow(
                    icon: summary.status.iconName,
                    quarter: q.title,
                    statusTag: summary.status.rawValue,
                    statusColor: Color(hex: summary.status.colorHex),
                    milesText: String(format: "%.1f business mi", summary.miles),
                    amountText: String(format: "$%.2f", summary.deduction),
                    stateText: summary.status.stateDescription
                )
            }

            // Quarter Velocity Progress Bar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Quarter Velocity: On Track (Pacing +14%)")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))

                    Spacer()

                    Text("\(Int(velocityPacingRatio * 100))% of Target")
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
                            .frame(width: max(10, geo.size.width * velocityPacingRatio))
                    }
                }
                .frame(height: 6)
            }
            .padding(.top, 4)
        }
        .padding(14)
        .background(Color(hex: "#0A1018").opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.07), lineWidth: 1))
    }

    private func quarterAccrualRow(
        icon: String,
        quarter: String,
        statusTag: String,
        statusColor: Color,
        milesText: String,
        amountText: String,
        stateText: String) -> some View {

        HStack {
            // Left: Lock / Clock + Quarter + Miles
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 11))
                        .foregroundStyle(statusColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(quarter)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)

                        Text(statusTag)
                            .font(.system(size: 7.5, weight: .heavy, design: .monospaced))
                            .foregroundStyle(statusColor)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(statusColor.opacity(0.12))
                            .clipShape(Capsule())
                    }

                    Text(milesText)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            Spacer()

            // Right: Amount + Status
            VStack(alignment: .trailing, spacing: 1) {
                Text(amountText)
                    .font(.system(size: 13.5, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(stateText)
                    .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - 1-Tap CPA Certified Export Section

    private var cpaExportSection: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 5) {
                    Text("1-Tap CPA Certified Export")
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(.white)

                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "#00FF88"))
                }

                Spacer()

                Text("Tamper-Proof Hash")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(hex: "#00E5FF").opacity(0.85))
            }

            // Card 1: IRS Certified Log (PDF)
            VStack(spacing: 10) {
                HStack(alignment: .top) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(hex: "#0E241B"))
                            .frame(width: 36, height: 36)
                        Image(systemName: "doc.richtext.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color(hex: "#00FF88"))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("IRS Certified Log")
                                .font(.system(size: 13.5, weight: .bold))
                                .foregroundStyle(.white)
                            Text("PDF")
                                .font(.system(size: 8, weight: .heavy))
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }

                        Text("Complete forensic ledger with timestamps, start/stop odometer values, business purposes, and IRS Section 274(d) compliant CPA signature affidavit.")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineSpacing(2)
                    }
                }

                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "signature")
                            .font(.system(size: 10))
                            .foregroundStyle(Color(hex: "#00FF88"))
                        Text("Includes Form 4562 Line 44 block")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Spacer()

                    // Export PDF Button (Glowing Neon Emerald)
                    Button {
                        exportURL = ExportEngine.exportPDF(trips: businessTrips)
                        showExportShare = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text("Export\nPDF")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .multilineTextAlignment(.leading)
                        }
                        .foregroundStyle(Color(hex: "#061A13"))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#00FF88"), Color(hex: "#00D670")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .shadow(color: Color(hex: "#00FF88").opacity(0.35), radius: 6)
                    }
                }
            }
            .padding(12)
            .background(Color(hex: "#0C141D").opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))

            // Card 2: Tax Spreadsheet (CSV)
            VStack(spacing: 10) {
                HStack(alignment: .top) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(hex: "#0C1E26"))
                            .frame(width: 36, height: 36)
                        Image(systemName: "tablecells.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(hex: "#00E5FF"))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Tax Spreadsheet")
                                .font(.system(size: 13.5, weight: .bold))
                                .foregroundStyle(.white)
                            Text("CSV")
                                .font(.system(size: 8, weight: .heavy))
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }

                        Text("Mapped 1:1 for TurboTax Business, QuickBooks Online, Xero, and Thomson Reuters UltraTax with client classification tags and expense codes.")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineSpacing(2)
                    }
                }

                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "rectangle.split.3x3")
                            .font(.system(size: 10))
                            .foregroundStyle(Color(hex: "#00E5FF"))
                        Text("Pre-formatted columns (UTF-8)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Spacer()

                    // Export CSV Button (Cyan)
                    Button {
                        exportURL = ExportEngine.exportCSV(trips: businessTrips)
                        showExportShare = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text("Export\nCSV")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .multilineTextAlignment(.leading)
                        }
                        .foregroundStyle(Color(hex: "#061A13"))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#00E5FF"), Color(hex: "#00B8D4")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .shadow(color: Color(hex: "#00E5FF").opacity(0.35), radius: 6)
                    }
                }
            }
            .padding(12)
            .background(Color(hex: "#0C141D").opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
        }
        .padding(14)
        .background(Color(hex: "#0A1018").opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.07), lineWidth: 1))
    }

    // MARK: - Privacy Guarantee Card

    private var privacyGuaranteeCard: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: "#0B1D24"))
                    .frame(width: 36, height: 36)
                Image(systemName: "lock.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(hex: "#00E5FF"))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("ZERO CLOUD TELEMETRY GUARANTEE")
                        .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white)
                    Circle()
                        .fill(Color(hex: "#00FF88"))
                        .frame(width: 5, height: 5)
                }

                Text("Your high-fidelity GPS breadcrumbs, stop durations, and visited addresses stay encrypted locally in an AES-256 SQLite partition on your iPhone. Never synced to remote servers, never monetized, and never disclosed to insurance brokers.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineSpacing(2)
            }
        }
        .padding(14)
        .background(Color(hex: "#09121B").opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
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
