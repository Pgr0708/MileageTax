//
//  PaywallScreenView.swift
//  MileageTax — Premium Paywall with RevenueCat Backend
//

import SwiftUI
import RevenueCat
import SafariServices

struct PaywallScreenView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppStorageKeys.hasSeenPaywall) private var hasSeenPaywall = false
    @StateObject private var vm = ProViewModel()
    @State private var counterValue: Double = 0
    @State private var heroScale: CGFloat = 0.92
    @State private var heroOpacity: Double = 0
    @State private var featuresVisible = false
    @State private var safariURL: URL? = nil
    @State private var showRestoreAlert = false
    @State private var restoreMessage = ""

    private let targetSaved: Double = 4847
    private let features: [(icon: String, text: String, sub: String)] = [
        ("infinity",                  "Unlimited Trip Logging",    "No cap on drives per month"),
        ("building.columns.fill",     "IRS §162/274 Compliance",   "Audit-ready PDF reports"),
        ("location.viewfinder",       "Kalman GPS Precision",      "±5m accuracy, sub-meter routing"),
        ("antenna.radiowaves.left.and.right", "Auto-Detect Radar","Starts before you know you're driving"),
        ("square.and.arrow.up",       "CSV & PDF Export",          "One-tap IRS-ready documents"),
        ("lock.shield.fill",          "On-Device Privacy",         "Your data never leaves your phone"),
        ("bell.badge.fill",           "Smart Notifications",       "Weekly tax yield summaries")
    ]

    var body: some View {
        ZStack {
            Color(hex: "#06090E").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Top Bar with Scrollable Dismiss Button (scrolls with content, not in ZStack)
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                hasSeenPaywall = true
                                dismiss()
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white.opacity(0.85))
                                .frame(width: 34, height: 34)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Circle())
                                .overlay(Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                        }
                        .padding(.trailing, 20)
                        .padding(.top, max(Device.topSafeArea, 50) + 4)
                    }

                    heroSection
                    savingsCounter
                    plansSection
                    featuresSection
                    trustRow
                    legalFooter
                    Spacer().frame(height: 40)
                }
            }

            // Loading overlay
            if vm.isLoading {
                ZStack {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(Color(hex: "#00FF88"))
                            .scaleEffect(1.5)
                        Text("Connecting...")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(32)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
            }
        }
        .onAppear {
            vm.getOffering()
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.1)) {
                heroScale = 1.0; heroOpacity = 1
            }
            withAnimation(.easeOut(duration: 2.2).delay(0.4)) {
                counterValue = targetSaved
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.7)) {
                featuresVisible = true
            }
        }
        .alert("Restore Purchases", isPresented: $showRestoreAlert) {
            Button("OK") {}
        } message: {
            Text(restoreMessage)
        }
        .sheet(item: Binding(
            get: { safariURL.map { IdentifiableURL(url: $0) } },
            set: { safariURL = $0?.url }
        )) { idUrl in
            SafariView(url: idUrl.url)
        }
    }

    // MARK: - Hero
    private var heroSection: some View {
        ZStack {
            // Background glow
            RadialGradient(colors: [Color(hex: "#00FF88").opacity(0.18), .clear],
                           center: .center, startRadius: 10, endRadius: 220)
                .frame(height: 280)

            VStack(spacing: 8) {
                // PRO badge
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9, weight: .black))
                    Text("MILEAGETAX PRO")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                }
                .foregroundStyle(Color(hex: "#06090E"))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    LinearGradient(colors: [Color(hex: "#00FF88"), Color(hex: "#00D670")],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(Capsule())
                .padding(.top, 8)

                // Animated speedometer icon
                ZStack {
                    ForEach(0..<3) { i in
                        Circle()
                            .strokeBorder(Color(hex: "#00FF88").opacity(0.08 - Double(i) * 0.02), lineWidth: 1)
                            .frame(width: CGFloat(90 + i * 30), height: CGFloat(90 + i * 30))
                    }
                    ZStack {
                        Circle()
                            .fill(RadialGradient(colors: [Color(hex: "#0E2820"), Color(hex: "#06090E")],
                                                  center: .center, startRadius: 10, endRadius: 50))
                            .frame(width: 96, height: 96)
                            .overlay(Circle().strokeBorder(Color(hex: "#00FF88").opacity(0.4), lineWidth: 2))
                        Image(systemName: "speedometer")
                            .font(.system(size: 36, weight: .black))
                            .foregroundStyle(
                                LinearGradient(colors: [Color(hex: "#00E5FF"), Color(hex: "#00FF88")],
                                               startPoint: .top, endPoint: .bottom)
                            )
                    }
                }
                .scaleEffect(heroScale)
                .opacity(heroOpacity)

                Text("Unlock Your\nTax Potential")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .opacity(heroOpacity)

                Text("Join 50,000+ drivers saving thousands\nevery year with full automation.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .opacity(heroOpacity)
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 28)
        }
    }

    // MARK: - Savings Counter
    private var savingsCounter: some View {
        VStack(spacing: 4) {
            Text("AVG. ANNUAL SAVINGS")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("$")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: "#00FF88"))
                Text(String(format: "%.0f", counterValue))
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: "#00FF88"))
                    .shadow(color: Color(hex: "#00FF88").opacity(0.5), radius: 12)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 2.0), value: counterValue)
            }

            Text("in IRS-verified tax deductions")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(Color(hex: "#0A1018").opacity(0.6))
        .overlay(
            Rectangle()
                .fill(Color(hex: "#00FF88").opacity(0.08))
                .frame(height: 1),
            alignment: .top
        )
        .overlay(
            Rectangle()
                .fill(Color(hex: "#00FF88").opacity(0.08))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Plans Section (strictly loaded from RevenueCat PaywallViewModel)
    private var plansSection: some View {
        VStack(spacing: 12) {
            Text("CHOOSE YOUR PLAN")
                .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.top, 24)

            if vm.isLoading && vm.allPackages.isEmpty {
                // Shimmering skeleton while RevenueCat loads
                ForEach(0..<3) { _ in
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(hex: "#0E1622"))
                        .frame(height: 72)
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.06)))
                        .redacted(reason: .placeholder)
                }
            } else if vm.allPackages.isEmpty {
                // Empty state when RevenueCat has no packages returned
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Color(hex: "#00FF88"))

                    Text("No Plans Available")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Unable to load subscription plans from RevenueCat. Please check your network or RevenueCat offering configuration.")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    Button {
                        vm.getOffering()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .bold))
                            Text("Retry")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(Color(hex: "#06090E"))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(Color(hex: "#00FF88"))
                        .clipShape(Capsule())
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                .background(Color(hex: "#0A1018").opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.08)))
            } else {
                // Live packages loaded from RevenueCat ProViewModel
                ForEach(vm.allPackages, id: \.identifier) { pkg in
                    planTile(pkg)
                }
            }

            // Purchase CTA
            Button {
                vm.makePurchases {
                    hasSeenPaywall = true
                    dismiss()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14, weight: .black))
                    Text(vm.selectedPackage != nil ? "Unlock Pro — \(vm.selectedPackage!.localizedPriceString)" : "Unlock Pro")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(Color(hex: "#06090E"))
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(
                    LinearGradient(colors: [Color(hex: "#00E5FF"), Color(hex: "#00FF88")],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(Capsule())
                .shadow(color: Color(hex: "#00E5FF").opacity(0.5), radius: 16, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(vm.selectedPackage == nil || vm.isLoading)
            .opacity(vm.selectedPackage == nil ? 0.6 : 1.0)
            .padding(.top, 4)
        }
        .padding(.horizontal, 24)
    }

    private func planTile(_ pkg: Package) -> some View {
        let isSelected = vm.selectedPackage?.identifier == pkg.identifier
        let isPopular  = pkg.packageType == .annual
        return Button {
            withAnimation(.spring(response: 0.3)) { vm.selectedPackage = pkg }
        } label: {
            HStack(spacing: 14) {
                // Radio circle
                ZStack {
                    Circle().strokeBorder(isSelected ? Color(hex: "#00FF88") : Color.white.opacity(0.2), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle().fill(Color(hex: "#00FF88")).frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(planLabel(pkg))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                        if isPopular {
                            Text("BEST VALUE")
                                .font(.system(size: 7.5, weight: .heavy, design: .monospaced))
                                .foregroundStyle(Color(hex: "#06090E"))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: "#00FF88"))
                                .clipShape(Capsule())
                        }
                    }
                    Text(planSubtitle(pkg))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                Text(pkg.localizedPriceString)
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundStyle(isSelected ? Color(hex: "#00FF88") : .white.opacity(0.8))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                ZStack {
                    Color(hex: isSelected ? "#0D2218" : "#0E1622")
                    if isSelected {
                        LinearGradient(colors: [Color(hex: "#00FF88").opacity(0.08), .clear],
                                       startPoint: .leading, endPoint: .trailing)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? Color(hex: "#00FF88").opacity(0.6) : Color.white.opacity(0.07), lineWidth: isSelected ? 1.5 : 1)
            )
            .shadow(color: isSelected ? Color(hex: "#00FF88").opacity(0.15) : .clear, radius: 8)
        }
        .buttonStyle(.plain)
    }

    private func planLabel(_ pkg: Package) -> String {
        switch pkg.packageType {
        case .annual:   return "Annual Pro"
        case .monthly:  return "Monthly Pro"
        case .lifetime: return "Lifetime Pro"
        default:        return pkg.identifier
        }
    }

    private func planSubtitle(_ pkg: Package) -> String {
        switch pkg.packageType {
        case .annual:   return "Best value · ~\(String(format: "$%.2f", NSDecimalNumber(decimal: pkg.storeProduct.price).doubleValue / 12))/month"
        case .monthly:  return "Cancel anytime · billed monthly"
        case .lifetime: return "One-time purchase · forever"
        default:        return ""
        }
    }

    // MARK: - Features
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("EVERYTHING INCLUDED")
                .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.bottom, 14)
                .padding(.top, 28)

            VStack(spacing: 0) {
                ForEach(Array(features.enumerated()), id: \.offset) { idx, f in
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(hex: "#0D2218"))
                                .frame(width: 34, height: 34)
                            Image(systemName: f.icon)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color(hex: "#00FF88"))
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(f.text)
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(.white)
                            Text(f.sub)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                        Spacer()
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(Color(hex: "#00FF88"))
                    }
                    .padding(.vertical, 12)
                    .opacity(featuresVisible ? 1 : 0)
                    .offset(x: featuresVisible ? 0 : 24)
                    .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(Double(idx) * 0.07), value: featuresVisible)

                    if idx < features.count - 1 {
                        Divider().background(Color.white.opacity(0.06))
                    }
                }
            }
            .padding(16)
            .background(Color(hex: "#0A1018").opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.07)))
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Trust Row
    private var trustRow: some View {
        HStack(spacing: 0) {
            ForEach(["4.9★ Rating", "50K+ Drivers", "IRS Compliant"], id: \.self) { item in
                Text(item)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(maxWidth: .infinity)
                if item != "IRS Compliant" {
                    Divider().background(Color.white.opacity(0.12)).frame(height: 16)
                }
            }
        }
        .padding(.vertical, 20)
        .padding(.top, 8)
        .padding(.horizontal, 24)
    }

    // MARK: - Legal Footer
    private var legalFooter: some View {
        VStack(spacing: 14) {
            Button {
                if Purchases.isConfigured {
                    vm.restorePurchases {
                        hasSeenPaywall = true
                        dismiss()
                    }
                } else {
                    restoreMessage = "RevenueCat is not configured. Purchase restoration is available when connected to App Store Connect."
                    showRestoreAlert = true
                }
            } label: {
                Text("Restore Purchases")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(hex: "#00E5FF"))
            }

            HStack(spacing: 16) {
                Button("Privacy Policy") { safariURL = URL(string: "https://mileagetax.app/privacy") }
                Text("•").foregroundStyle(.white.opacity(0.2))
                Button("Terms of Service") { safariURL = URL(string: "https://mileagetax.app/terms") }
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(0.4))

            Text("Subscriptions auto-renew unless cancelled 24h before renewal. Prices may vary by region.")
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(.white.opacity(0.25))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
}

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
