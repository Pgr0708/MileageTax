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
    @AppStorage(AppStorageKeys.irsRateOverride) private var irsRate: Double = MileageTaxDefaults.irsRatePerMile
    @AppStorage(AppStorageKeys.userName) private var userName: String = "Julian Vance"

    // Toggles persisted to AppStorage
    @AppStorage("MT_cpaAuditShieldEnabled") private var cpaAuditShieldEnabled = true
    @AppStorage("MT_icloudBackupEnabled")    private var icloudBackupEnabled = true
    @AppStorage("MT_faceIDLockEnabled")      private var faceIDLockEnabled = true
    @AppStorage(AppStorageKeys.isLoggedIn)   private var isLoggedIn = true
    @State private var avatarGlowPhase = false

    // Real Metrics from CoreData
    private var totalMiles: Double {
        trips.filter { $0.tripClassification == .business }.reduce(0) { $0 + $1.totalDistanceMiles }
    }
    private var totalYield: Double {
        trips.filter { $0.tripClassification == .business }.reduce(0) { $0 + $1.taxDeductionValueUSD }
    }

    var body: some View {
        NavigationStack {
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
                        irsComplianceCard

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
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                avatarGlowPhase = true
            }
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            HStack(spacing: 10) {
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

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white.opacity(0.6))
            }
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

            // Status Pill: PRO SUBSCRIBER
            HStack(spacing: 5) {
                Circle()
                    .fill(Color(hex: "#00FF88"))
                    .frame(width: 6, height: 6)

                Text("PRO SUBSCRIBER • LIFETIME TIER")
                    .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color(hex: "#00FF88"))
                    .tracking(0.5)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Color(hex: "#071F17"))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color(hex: "#00FF88").opacity(0.3), lineWidth: 1))

            // Name & Title
            VStack(spacing: 3) {
                Text(userName.isEmpty ? "Julian Vance" : userName)
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

                    Text(String(format: "$%.0f", totalYield))
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

            Divider().background(Color.white.opacity(0.06))

            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: "#00FF88"))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("BLE Sensor Beacon")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                        Text("14ms Ultralow Latency")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(hex: "#00FF88"))
                    }
                }

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "externaldrive.connected.to.line.below.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: "#00E5FF"))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("OBD-II Telemetry")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                        Text("Auto-Paired")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(hex: "#00E5FF"))
                    }
                }
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
                    Text("Auto-updating standard mileage rates")
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

                Text("1.1%/hr")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: "#00FF88"))
            }

            Divider().background(Color.white.opacity(0.06))

            HStack {
                Text("DRAIN VS TRADITIONAL TRACKERS")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
                Spacer()
                Text("-87% Battery Impact")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(hex: "#00FF88"))
            }

            // Bar comparisons
            VStack(spacing: 8) {
                // Pro HUD
                HStack(spacing: 8) {
                    Text("Pro HUD")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 70, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08))
                            Capsule()
                                .fill(Color(hex: "#00FF88"))
                                .frame(width: geo.size.width * 0.15)
                        }
                    }
                    .frame(height: 8)

                    Text("1.1%/h")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "#00FF88"))
                }

                // Legacy GPS
                HStack(spacing: 8) {
                    Text("Legacy GPS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(width: 70, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08))
                            Capsule()
                                .fill(Color(hex: "#FF6B6B").opacity(0.8))
                                .frame(width: geo.size.width * 0.75)
                        }
                    }
                    .frame(height: 8)

                    Text("8.5%/h")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "#FF6B6B"))
                }
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

            HStack(spacing: 10) {
                // QuickBooks
                HStack(spacing: 5) {
                    Image(systemName: "briefcase.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(hex: "#00FF88"))
                    Text("QuickBooks ●")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())

                // TurboTax
                HStack(spacing: 5) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(hex: "#00E5FF"))
                    Text("TurboTax ●")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())

                Spacer()
            }

            Divider().background(Color.white.opacity(0.06))

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
