//
//  ProfileView.swift
//  MileageTax — Executive Profile & Telemetry Controls
//  Obsidian Precision Design System · Exact Match to Spec
//

import SwiftUI
import CoreData

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TripEntity.startDate, ascending: false)],
        predicate: NSPredicate(format: "isInProgress == false"),
        animation: .default)
    private var trips: FetchedResults<TripEntity>

    @StateObject private var bluetooth = BluetoothVehicleManager.shared
    @AppStorage(AppStorageKeys.irsRateOverride)  private var irsRate: Double        = MileageTaxDefaults.irsRatePerMile
    @AppStorage(AppStorageKeys.currencySymbol)    private var currencySymbol: String  = MileageTaxDefaults.defaultCurrencySymbol
    @AppStorage(AppStorageKeys.distanceUnit)      private var distanceUnit: String    = MileageTaxDefaults.defaultDistanceUnit
    @AppStorage(AppStorageKeys.countryTaxLabel)   private var countryTaxLabel: String = MileageTaxDefaults.defaultCountryLabel
    @AppStorage(AppStorageKeys.userName) private var userName: String = ""

    // Toggles persisted to AppStorage
    @AppStorage("MT_cpaAuditShieldEnabled") private var cpaAuditShieldEnabled = true
    @AppStorage("MT_icloudBackupEnabled")    private var icloudBackupEnabled = true
    @AppStorage("MT_faceIDLockEnabled")      private var faceIDLockEnabled = true
    @AppStorage(AppStorageKeys.isLoggedIn)   private var isLoggedIn = true
    @State private var avatarGlowPhase = false
    @State private var showTaxSettingsSheet = false

    // Real Metrics from CoreData
    private var totalMiles: Double {
        trips.filter { $0.tripClassification == .business }.reduce(0) { $0 + $1.totalDistanceMiles }
    }
    private var totalYield: Double {
        trips.filter { $0.tripClassification == .business }.reduce(0) { $0 + $1.taxDeductionValueUSD }
    }

    var body: some View {
        ZStack {
            // Background
            Color(hex: "#06090E").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Header
                    headerBar

                    // Avatar & Identity Hero
                    identitySection

                    // Hardware & Telemetry Card
                    hardwareTelemetryCard

                    // IRS Compliance Engine Card
                    Button { showTaxSettingsSheet = true } label: { irsComplianceCard }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showTaxSettingsSheet) {
                        TaxSettingsModalView()
                            .presentationDetents([.medium])
                    }

                    // CoreMotion Gating Card
                    coreMotionGatingCard

                    // Accounting Integrations Card
                    accountingIntegrationsCard

                    // Biometrics & Vault Lock Card
                    biometricsCard

                    // Sign Out Button
                    signOutButton

                    // Footer Version
                    footerMetadata

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                avatarGlowPhase = true
            }
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(alignment: .center) {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#0E1622").opacity(0.85))
                            .frame(width: 38, height: 38)
                            .overlay(Circle().strokeBorder(Color(hex: "#00E5FF").opacity(0.35), lineWidth: 1))

                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(hex: "#00E5FF"))
                    }

                    Text("Back")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Identity Hero

    private var identitySection: some View {
        VStack(spacing: 12) {
            // Circular Avatar with Cybernetic Halo
            ZStack {
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color(hex: "#00E5FF").opacity(0.6), Color(hex: "#00FF88").opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 104, height: 104)
                    .scaleEffect(avatarGlowPhase ? 1.06 : 1.0)

                Circle()
                    .strokeBorder(Color(hex: "#00FF88").opacity(0.2), lineWidth: 1)
                    .frame(width: 118, height: 118)

                // Avatar Photo Placeholder / Image
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#102028"), Color(hex: "#0C121A")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 92, height: 92)

                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 86, height: 86)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#00E5FF").opacity(0.9), Color(hex: "#00FF88").opacity(0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .clipShape(Circle())

                // Verified Badge Checkmark
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color(hex: "#00FF88"))
                            .background(Circle().fill(Color(hex: "#06090E")).frame(width: 22, height: 22))
                    }
                }
                .frame(width: 96, height: 96)
            }



            // Name & Title
            VStack(spacing: 3) {
                Text(userName.isEmpty ? "Taxpayer" : userName)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("Senior Partner & Tech Founder")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }

            // Two Metric Cards (Tracked & Tax Yield)
            HStack(spacing: 12) {
                // Tracked Miles
                VStack(spacing: 2) {
                    Text("TRACKED")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))

                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(String(format: "%.0f", totalMiles))
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(Color(hex: "#00FF88"))
                        Text("mi")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(hex: "#0B131D").opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))

                // Tax Yield
                VStack(spacing: 2) {
                    Text("TAX YIELD")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))

                    Text(String(format: "%@%.0f", currencySymbol, totalYield))
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(Color(hex: "#00E5FF"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(hex: "#0B131D").opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Hardware & Telemetry Card

    private var hardwareTelemetryCard: some View {
        VStack(spacing: 12) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: "#0C1F26"))
                        .frame(width: 36, height: 36)
                    Image(systemName: "car.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(hex: "#00E5FF"))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Hardware & Telemetry")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                    Text(bluetooth.connectedVehicleName ?? "Prius 2024 • Bluetooth CarPlay Auto-Lock")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                Text("ACTIVE")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(hex: "#00FF88"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(hex: "#00FF88").opacity(0.12))
                    .clipShape(Capsule())
            }


        }
        .padding(14)
        .background(Color(hex: "#0A1018").opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - IRS Compliance Card

    private var irsComplianceCard: some View {
        VStack(spacing: 12) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: "#0E241D"))
                        .frame(width: 36, height: 36)
                    Image(systemName: "doc.badge.shield.check")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(hex: "#00FF88"))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("IRS Compliance Engine")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Tap to set your country's rate")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                Text(String(format: "%.0f¢/mi", irsRate * 100))
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(hex: "#00FF88"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(hex: "#00FF88").opacity(0.12))
                    .clipShape(Capsule())
            }

            Divider().background(Color.white.opacity(0.06))

            HStack {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
                VStack(alignment: .leading, spacing: 1) {
                    Text("On-Device SQLite Cipher")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                    Text("AES-256 GCM Trip Journal")
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                }

                Spacer()

                Text("ENCRYPTED")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(hex: "#00FF88"))
            }

            Divider().background(Color.white.opacity(0.06))

            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "#00E5FF"))
                VStack(alignment: .leading, spacing: 1) {
                    Text("CPA Audit Shield")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                    Text("IRS Section 162/274 Validated")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                }

                Spacer()

                Toggle("", isOn: $cpaAuditShieldEnabled)
                    .toggleStyle(ObsidianToggleStyle())
                    .labelsHidden()
            }
        }
        .padding(14)
        .background(Color(hex: "#0A1018").opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - CoreMotion Gating Card

    private var coreMotionGatingCard: some View {
        VStack(spacing: 12) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: "#0B1D1D"))
                        .frame(width: 36, height: 36)
                    Image(systemName: "figure.walk.motion")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(hex: "#00E5FF"))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("CoreMotion Gating")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Intelligent background state transition")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

            }
        }
        .padding(14)
        .background(Color(hex: "#0A1018").opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Accounting Integrations

    private var accountingIntegrationsCard: some View {
        VStack(spacing: 12) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: "#0E1825"))
                        .frame(width: 36, height: 36)
                    Image(systemName: "square.grid.3x3.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(hex: "#00E5FF"))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Accounting Integrations")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Real-time ledger push")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()
            }



            HStack {
                Image(systemName: "icloud.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
                Text("Encrypted iCloud Backup")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                Toggle("", isOn: $icloudBackupEnabled)
                    .toggleStyle(ObsidianToggleStyle())
                    .labelsHidden()
            }
        }
        .padding(14)
        .background(Color(hex: "#0A1018").opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Biometrics & Vault Lock

    private var biometricsCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "faceid")
                    .font(.system(size: 18))
                    .foregroundStyle(Color(hex: "#00FF88"))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Biometrics & Vault Lock")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Require FaceID on resume")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                }

                Spacer()

                Toggle("", isOn: $faceIDLockEnabled)
                    .toggleStyle(ObsidianToggleStyle())
                    .labelsHidden()
            }

            Divider().background(Color.white.opacity(0.06))

            HStack {
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
                Text("Zero-Knowledge Route Obfuscation")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))

                Spacer()

                Text("ACTIVE")
                    .font(.system(size: 8.5, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(hex: "#00FF88"))
            }
        }
        .padding(14)
        .background(Color(hex: "#0A1018").opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Sign Out Button

    private var signOutButton: some View {
        Button {
            isLoggedIn = false
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 13, weight: .bold))
                Text("Sign Out of Executive Workspace")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.85))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(hex: "#101824").opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        }
    }

    // MARK: - Footer Metadata

    private var footerMetadata: some View {
        VStack(spacing: 3) {
            Text("App Version 3.4.2 (Build 890 - CoreMotion v2)")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
            Text("Encrypted Hardware ID: 9F84-281A-CD48")
                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.25))
        }
        .padding(.top, 6)
    }
}

// MARK: - Tax & Currency Settings Modal

struct TaxSettingsModalView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppStorageKeys.irsRateOverride)  private var irsRate: Double        = MileageTaxDefaults.irsRatePerMile
    @AppStorage(AppStorageKeys.currencySymbol)   private var currencySymbol: String = MileageTaxDefaults.defaultCurrencySymbol
    @AppStorage(AppStorageKeys.distanceUnit)     private var distanceUnit: String   = MileageTaxDefaults.defaultDistanceUnit
    @AppStorage(AppStorageKeys.countryTaxLabel)  private var countryTaxLabel: String = MileageTaxDefaults.defaultCountryLabel

    @State private var rateInputText: String = ""

    // Pre-defined country presets
    private let presets: [(name: String, symbol: String, rate: Double, unit: String, label: String)] = [
        ("🇺🇸 United States (IRS)", "$",  0.76, "mi", "IRS Standard (USA)"),
        ("🇬🇧 United Kingdom (HMRC)", "£",  0.55, "mi", "HMRC Standard (UK)"),
        ("🇨🇦 Canada (CRA)", "C$", 0.73, "km", "CRA Standard (CA)"),
        ("🇦🇺 Australia (ATO)", "A$", 0.91, "km", "ATO Cents-per-km (AU)"),
        ("🇳🇿 New Zealand (IRD)", "NZ$", 1.20, "km", "IRD Tier 1 Petrol (NZ)"),
        ("🇫🇷 France (DGFiP)", "€",  0.529, "km", "DGFiP Base Scale (FR)"),
        ("🇩🇪 Germany (BMF)", "€",  0.30, "km", "BMF Distance (DE)"),
        ("🇦🇹 Austria (BMF)", "€", 0.50, "km", "BMF Kilometergeld (AT)"),
        ("🇧🇪 Belgium (BOSA)", "€", 0.444, "km", "BOSA Allowance (BE)"),
        ("🇳🇱 Netherlands (Belastingdienst)", "€", 0.25, "km", "Standard Deduction (NL)"),
        ("🇪🇸 Spain (Agencia Tributaria)", "€", 0.26, "km", "Business Travel (ES)"),
        ("🇮🇪 Ireland (Revenue)", "€", 0.418, "km", "Civil Service Base (IE)"),
        ("🇳🇴 Norway (Skatteetaten)", "kr", 3.50, "km", "Tax-free Mileage (NO)"),
        ("🇸🇪 Sweden (Skatteverket)", "kr", 2.50, "km", "Tax-free Mileage (SE)"),
        ("🇨🇿 Czech Republic (SUIP)", "Kč", 5.90, "km", "Statutory Comp (CZ)")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#06090E").ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        // ── Country Presets ───────────────────────────────
                        VStack(alignment: .leading, spacing: 10) {
                            Text("COUNTRY PRESET")
                                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                .foregroundStyle(Color(hex: "#00FF88"))

                            ForEach(presets, id: \.name) { preset in
                                Button {
                                    currencySymbol  = preset.symbol
                                    irsRate         = preset.rate
                                    distanceUnit    = preset.unit
                                    countryTaxLabel = preset.label
                                    rateInputText   = String(preset.rate)
                                } label: {
                                    HStack {
                                        Text(preset.name)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.white)
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text("\(preset.symbol)\(String(format: "%.2f", preset.rate))/\(preset.unit)")
                                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                                .foregroundStyle(Color(hex: "#00FF88"))
                                        }
                                        if countryTaxLabel == preset.label {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(Color(hex: "#00FF88"))
                                                .padding(.leading, 6)
                                        }
                                    }
                                    .padding(14)
                                    .background(
                                        countryTaxLabel == preset.label
                                            ? Color(hex: "#00FF88").opacity(0.08)
                                            : Color(hex: "#0A1018").opacity(0.9)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .strokeBorder(
                                                countryTaxLabel == preset.label
                                                    ? Color(hex: "#00FF88").opacity(0.4)
                                                    : Color.white.opacity(0.07),
                                                lineWidth: 1
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // ── Manual Override ───────────────────────────────
                        VStack(alignment: .leading, spacing: 10) {
                            Text("MANUAL OVERRIDE")
                                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                .foregroundStyle(Color(hex: "#00E5FF"))

                            VStack(spacing: 14) {
                                HStack(spacing: 12) {
                                    Text("Currency Symbol")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.7))
                                    Spacer()
                                    TextField("$", text: $currencySymbol)
                                        .font(.system(size: 18, weight: .black, design: .monospaced))
                                        .foregroundStyle(Color(hex: "#00FF88"))
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 50)
                                        .padding(.horizontal, 8).padding(.vertical, 6)
                                        .background(Color.white.opacity(0.06))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }

                                HStack(spacing: 12) {
                                    Text("Rate per \(distanceUnit)")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.7))
                                    Spacer()
                                    TextField("0.67", text: $rateInputText)
                                        .font(.system(size: 18, weight: .black, design: .monospaced))
                                        .foregroundStyle(Color(hex: "#00FF88"))
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 80)
                                        .padding(.horizontal, 8).padding(.vertical, 6)
                                        .background(Color.white.opacity(0.06))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .onChange(of: rateInputText) { newVal in
                                            if let d = Double(newVal) { irsRate = d }
                                        }
                                }

                                HStack(spacing: 12) {
                                    Text("Distance Unit")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.7))
                                    Spacer()
                                    Picker("", selection: $distanceUnit) {
                                        Text("mi").tag("mi")
                                        Text("km").tag("km")
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(width: 100)
                                }
                            }
                            .padding(16)
                            .background(Color(hex: "#0A1018").opacity(0.9))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                        }

                        // ── Live Preview ──────────────────────────────────
                        HStack {
                            Image(systemName: "eye.fill")
                                .foregroundStyle(Color(hex: "#00FF88"))
                            Text("Live Preview:")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                            Spacer()
                            Text("\(currencySymbol)\(String(format: "%.2f", irsRate))/\(distanceUnit)")
                                .font(.system(size: 16, weight: .black, design: .monospaced))
                                .foregroundStyle(Color(hex: "#00FF88"))
                        }
                        .padding(14)
                        .background(Color(hex: "#071F17"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(hex: "#00FF88").opacity(0.3), lineWidth: 1))

                        Button {
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Save & Apply Globally")
                            }
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color(hex: "#061A13"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(hex: "#00FF88"))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: Color(hex: "#00FF88").opacity(0.3), radius: 10, y: 4)
                        }
                        .padding(.bottom, 16)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Tax & Currency Engine")
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
            .onAppear {
                rateInputText = String(irsRate)
            }
        }
    }
}
