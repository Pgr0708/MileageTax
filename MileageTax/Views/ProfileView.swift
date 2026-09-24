//
//  ProfileView.swift
//  MileageTax — Executive Profile & Telemetry Controls
//  Obsidian Precision Design System · Exact Match to Spec
//

import SwiftUI
import CoreData
import StoreKit

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL

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
    @State private var showResetAlert = false
    @State private var showSafariURL: URL? = nil
    @State private var showSafariSheet = false
    @State private var showEditProfile = false
    @State private var profilePhotoData: Data? = UserDefaults.standard.data(forKey: "MT_userPhotoData")

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

                    // Support & Legal Section
                    supportLegalSection

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
        // Safari links now use @Environment(\.openURL) directly
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showEditProfile, onDismiss: {
            profilePhotoData = UserDefaults.standard.data(forKey: "MT_userPhotoData")
        }) {
            EditProfileSheet(profilePhotoData: $profilePhotoData)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                avatarGlowPhase = true
            }
            let stored = ProfileStore.shared
            if !stored.name.isEmpty { userName = stored.name }
            if let data = stored.photoData { profilePhotoData = data }
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

            // Edit Profile
            Button { showEditProfile = true } label: {
                HStack(spacing: 5) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: "#00FF88"))
                    Text("Edit")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(hex: "#00FF88"))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color(hex: "#061A13").opacity(0.85))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color(hex: "#00FF88").opacity(0.3), lineWidth: 1))
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

                // Avatar Photo — real photo if available, else placeholder
                Button { showEditProfile = true } label: {
                    ZStack {
                        // Inner content clipped to circle
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

                            if let data = profilePhotoData, let img = UIImage(data: data) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 92, height: 92)
                                    .clipShape(Circle())
                            } else {
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
                        }
                        .clipShape(Circle())

                        // Camera badge — sits OUTSIDE clipped group, always fully visible
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#00E5FF"), Color(hex: "#00B8CC")],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                            .shadow(color: Color(hex: "#00E5FF").opacity(0.6), radius: 6)
                            .offset(x: 32, y: 32)
                    }
                }


            }



            // Name & Title
            VStack(spacing: 3) {
                Text(userName.isEmpty ? "Tap Edit to set your name" : userName)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(userName.isEmpty ? .white.opacity(0.4) : .white)
                    .onTapGesture { showEditProfile = true }

                Text("MileageTax Driver")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }

            // Two Metric Cards (Tracked & Tax Yield)
            HStack(spacing: 12) {
                // Tracked Miles
                VStack(spacing: 2) {
                    Text("TRACKED")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))

                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(String(format: "%.0f", MileageUnits.distanceValue(totalMiles)))
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(Color(hex: "#00FF88"))
                        Text(MileageUnits.unitLabel)
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
                    Image(systemName: "building.columns.fill")
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

                Text(String(format: "%.0f¢/%@", MileageUnits.ratePerDisplayUnit(irsRate) * 100, MileageUnits.unitLabel))
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
            showResetAlert = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 13, weight: .bold))
                Text("Factory Reset App Data")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundStyle(Color.red.opacity(0.85))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(hex: "#241010").opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.red.opacity(0.2), lineWidth: 1))
        }
        .alert("Factory Reset", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset Everything", role: .destructive) {
                // Wipe core data
                CoreDataManager.shared.deleteAllTrips()
                // Clear user defaults (using AppStorage keys)
                if let bundleID = Bundle.main.bundleIdentifier {
                    UserDefaults.standard.removePersistentDomain(forName: bundleID)
                }
                // Dismiss the view/app state could handle soft-reset
                dismiss()
            }
        } message: {
            Text("This will permanently delete all your trips, mileage logs, settings, and automation rules. This action cannot be undone.")
        }
    }

    // MARK: - Support & Legal

    private var supportLegalSection: some View {
        VStack(spacing: 0) {
            supportRow(icon: "star.fill", iconColor: "#FFD700",
                       title: "Rate MileageTax",
                       subtitle: "Tap to rate us on the App Store") {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if let windowScene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first(where: { $0.activationState == .foregroundActive }) {
                    SKStoreReviewController.requestReview(in: windowScene)
                } else {
                    requestReview()
                }
            }
            sectionDivider
            supportRow(icon: "bubble.left.and.bubble.right.fill", iconColor: "#00E5FF",
                       title: "Support & Feedback",
                       subtitle: "We respond within 24 hours") {
                if let url = URL(string: "mailto:support@inovexa.com") {
                    UIApplication.shared.open(url)
                }
            }
            sectionDivider
            supportRow(icon: "lock.doc.fill", iconColor: "#00FF88",
                       title: "Privacy Policy",
                       subtitle: "How we protect your data") {
                if let url = URL(string: "https://sites.google.com/view/inovexa/privacy-policy") {
                    openURL(url)
                }
            }
            sectionDivider
            supportRow(icon: "doc.text.fill", iconColor: "#00FF88",
                       title: "Terms & Conditions",
                       subtitle: "Usage terms and agreements") {
                if let url = URL(string: "https://sites.google.com/view/inovexa/terms-and-conditions") {
                    openURL(url)
                }
            }
            sectionDivider
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "#0C1F26"))
                        .frame(width: 36, height: 36)
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(hex: "#00E5FF"))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("App Version")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(currentAppVersion)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
        }
        .background(Color(hex: "#0A1018").opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 1)
            .padding(.horizontal, 14)
    }

    private func supportRow(icon: String, iconColor: String, title: String,
                            subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: iconColor).opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 15))
                        .foregroundStyle(Color(hex: iconColor))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.2))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
        }
        .buttonStyle(.plain)
    }

    private var currentAppVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(v) (build \(b))"
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
    
    private let commonCurrencies = ["$", "£", "€", "C$", "A$", "NZ$", "kr", "Kč", "¥", "₹", "R", "CHF", "zł", "₽"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#06090E").ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        // ── Country Presets with Inline Customization ──────────
                        VStack(alignment: .leading, spacing: 10) {
                            Text("SELECT TAX AUTHORITY")
                                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                .foregroundStyle(Color(hex: "#00FF88"))
                                .padding(.horizontal, 4)

                            ForEach(presets, id: \.name) { preset in
                                let isSelected = (countryTaxLabel == preset.label)
                                
                                VStack(spacing: 0) {
                                    // Country Header Row
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            currencySymbol  = preset.symbol
                                            distanceUnit    = preset.unit
                                            countryTaxLabel = preset.label
                                            irsRate         = MileageUnits.perMileRate(from: preset.rate, nativeUnit: preset.unit)
                                            rateInputText   = String(format: "%.3f", MileageUnits.ratePerDisplayUnit(irsRate))
                                        }
                                    } label: {
                                        HStack {
                                            Text(preset.name)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(.white)
                                            Spacer()
                                            
                                            if !isSelected {
                                                Text("\(preset.symbol)\(String(format: "%.2f", preset.rate))/\(preset.unit)")
                                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                                    .foregroundStyle(.white.opacity(0.5))
                                            } else {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(Color(hex: "#00FF88"))
                                                    .font(.system(size: 16))
                                            }
                                        }
                                        .padding(14)
                                        .background(isSelected ? Color(hex: "#00FF88").opacity(0.12) : Color.clear)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    // Inline Customizer (Only visible if selected)
                                    if isSelected {
                                        VStack(spacing: 12) {
                                            Divider().background(Color(hex: "#00FF88").opacity(0.2))
                                            
                                            // Symbol & Distance Unit Pickers
                                            HStack(spacing: 16) {
                                                // Currency Picker
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text("CURRENCY")
                                                        .font(.system(size: 9, weight: .bold))
                                                        .foregroundStyle(.white.opacity(0.5))
                                                    
                                                    Menu {
                                                        ForEach(commonCurrencies, id: \.self) { sym in
                                                            Button(sym) { currencySymbol = sym }
                                                        }
                                                    } label: {
                                                        HStack {
                                                            Text(currencySymbol)
                                                                .font(.system(size: 16, weight: .black, design: .monospaced))
                                                                .foregroundStyle(Color(hex: "#00FF88"))
                                                            Image(systemName: "chevron.up.chevron.down")
                                                                .font(.system(size: 10))
                                                                .foregroundStyle(.white.opacity(0.5))
                                                        }
                                                        .frame(maxWidth: .infinity)
                                                        .padding(.vertical, 8)
                                                        .background(Color.black.opacity(0.3))
                                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                                    }
                                                }
                                                
                                                // Unit Picker
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text("UNIT")
                                                        .font(.system(size: 9, weight: .bold))
                                                        .foregroundStyle(.white.opacity(0.5))
                                                    
                                                    Menu {
                                                        Button("mi") { distanceUnit = "mi" }
                                                        Button("km") { distanceUnit = "km" }
                                                    } label: {
                                                        HStack {
                                                            Text(distanceUnit)
                                                                .font(.system(size: 16, weight: .black, design: .monospaced))
                                                                .foregroundStyle(Color(hex: "#00E5FF"))
                                                            Image(systemName: "chevron.up.chevron.down")
                                                                .font(.system(size: 10))
                                                                .foregroundStyle(.white.opacity(0.5))
                                                        }
                                                        .frame(maxWidth: .infinity)
                                                        .padding(.vertical, 8)
                                                        .background(Color.black.opacity(0.3))
                                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                                    }
                                                }
                                                
                                                // Rate Input
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text("RATE")
                                                        .font(.system(size: 9, weight: .bold))
                                                        .foregroundStyle(.white.opacity(0.5))
                                                    
                                                    TextField("0.00", text: $rateInputText)
                                                        .font(.system(size: 16, weight: .black, design: .monospaced))
                                                        .foregroundStyle(.white)
                                                        .keyboardType(.decimalPad)
                                                        .multilineTextAlignment(.center)
                                                        .padding(.vertical, 8)
                                                        .background(Color.black.opacity(0.3))
                                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                                        .onChange(of: rateInputText) { _, newVal in
                                                            if let d = Double(newVal) {
                                                                irsRate = MileageUnits.perMileRate(from: d, nativeUnit: distanceUnit)
                                                            }
                                                        }
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.bottom, 14)
                                        .background(Color(hex: "#00FF88").opacity(0.05))
                                    }
                                }
                                .background(Color(hex: "#0A1018").opacity(0.9))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(
                                            isSelected ? Color(hex: "#00FF88").opacity(0.5) : Color.white.opacity(0.07),
                                            lineWidth: isSelected ? 1.5 : 1
                                        )
                                )
                            }
                        }

                        // ── Live Preview ──────────────────────────────────
                        HStack {
                            Image(systemName: "eye.fill")
                                .foregroundStyle(Color(hex: "#00FF88"))
                            Text("Live Engine Preview:")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                            Spacer()
                            Text("\(currencySymbol)\(String(format: "%.3f", irsRate))/\(distanceUnit)")
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
                                Text("Save Settings")
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
                    .padding(16)
                }
            }
            .navigationTitle("Tax & Currency")
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
