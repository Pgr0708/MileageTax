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
    /// When true the paywall is mandatory (free-trip limit reached): the close
    /// button is hidden and the only way out is purchasing or restoring.
    var isForced: Bool = false

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
                    heroSection
                    savingsCounter
                    plansSection
                    featuresSection
                    trustRow
                    legalFooter
                    Spacer().frame(height: 40)
                }
            }

            // Dismiss button overlay (hidden when the paywall is forced)
            VStack {
                HStack {
                    Spacer()
                    if !isForced {
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
                        .padding(.top, 16)
                    }
                }
                Spacer()
            }

            // Loading overlay
            if vm.isLoading {
                ZStack {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(DS.cyan)
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

    // MARK: - Hero (concept board 1, screen 8)
    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            ScenicBackdrop(style: .alpineDawn, horizon: 0.7, showRoad: false, seed: 13, photo: "scene_paywall")
                .frame(height: 330)
                .mask(LinearGradient(colors: [.black, .black, .clear], startPoint: .top, endPoint: .bottom))

            VStack(alignment: .leading, spacing: 10) {
                (Text("Go Further\nwith ").foregroundStyle(.white) + Text("MileageTax Pro").foregroundStyle(DS.cyan))
                    .font(DS.display(30))
                    .shadow(color: .black.opacity(0.6), radius: 8)
                Text("Unlock advanced features and get the most from every mile.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(heroOpacity)
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .overlay(alignment: .topTrailing) {
            GaugeArt(size: 100, value: 0.85)
                .scaleEffect(heroScale)
                .opacity(heroOpacity)
                .padding(.top, 96)
                .padding(.trailing, 20)
        }
    }

    // MARK: - Savings Counter
    private var savingsCounter: some View {
        VStack(spacing: 4) {
            Text("AVG. ANNUAL SAVINGS")
                .font(DS.tech(9))
                .foregroundStyle(.white.opacity(0.4))

            // One Text so the "$" and digits share a layout and can't overlap while counting.
            (Text("$ ").font(DS.display(28)) + Text(String(format: "%.0f", counterValue)).font(DS.display(52)))
                .foregroundStyle(DS.brandGradient)
                .shadow(color: DS.cyan.opacity(0.5), radius: 12)
                .contentTransition(.numericText(value: counterValue))
                .animation(.easeOut(duration: 2.0), value: counterValue)

            Text("in IRS-verified tax deductions")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(Color(hex: "#0A1018").opacity(0.6))
        .overlay(
            Rectangle()
                .fill(DS.cyan.opacity(0.08))
                .frame(height: 1),
            alignment: .top
        )
        .overlay(
            Rectangle()
                .fill(DS.cyan.opacity(0.08))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Plans Section (strictly loaded from RevenueCat PaywallViewModel)
    private var plansSection: some View {
        VStack(spacing: 12) {
            Text("CHOOSE YOUR PLAN")
                .font(DS.tech(9.5))
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
                        .foregroundStyle(DS.cyan)

                    Text("No Plans Available")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)

                    Text(vm.loadErrorMessage.isEmpty
                         ? "Unable to load subscription plans. Please check your connection."
                         : vm.loadErrorMessage)
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
                        .background(DS.cyan)
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
                HStack(spacing: 6) {
                    ForEach(vm.allPackages, id: \.identifier) { pkg in
                        planSegment(pkg)
                    }
                }
                .padding(5)
                .background(DS.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(DS.stroke))

                if let pkg = vm.selectedPackage {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(pkg.localizedPriceString)
                            .font(DS.display(34))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                        Text(periodSuffix(pkg))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(DS.text2)
                        Spacer()
                        if let save = annualSavingsPercent, pkg.packageType == .annual {
                            Text("\(save)% OFF")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundStyle(Color(hex: "#03141A"))
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(DS.green, in: Capsule())
                        }
                    }
                    .padding(.top, 6)
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
                    Text("Continue with Pro")
                        .font(DS.display(17))
                }
                .foregroundStyle(Color(hex: "#06090E"))
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(DS.cyan, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Color(hex: "#00E5FF").opacity(0.5), radius: 16, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(vm.selectedPackage == nil || vm.isLoading)
            .opacity(vm.selectedPackage == nil ? 0.6 : 1.0)
            .padding(.top, 4)
        }
        .padding(.horizontal, 24)
    }

    private func planSegment(_ pkg: Package) -> some View {
        let isSelected = vm.selectedPackage?.identifier == pkg.identifier
        return Button {
            withAnimation(.spring(response: 0.3)) { vm.selectedPackage = pkg }
        } label: {
            VStack(spacing: 3) {
                Text(planLabel(pkg).replacingOccurrences(of: " Pro", with: ""))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Text(segmentHint(pkg))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isSelected ? DS.cyan : DS.text3)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(isSelected ? DS.cyan.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isSelected ? DS.cyan : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    /// Annual saving vs. paying monthly for a year, when both packages exist.
    private var annualSavingsPercent: Int? {
        guard let annual = vm.allPackages.first(where: { $0.packageType == .annual }),
              let monthly = vm.allPackages.first(where: { $0.packageType == .monthly }) else { return nil }
        let a = NSDecimalNumber(decimal: annual.storeProduct.price).doubleValue
        let m = NSDecimalNumber(decimal: monthly.storeProduct.price).doubleValue * 12
        guard m > 0, a < m else { return nil }
        return Int(((1 - a / m) * 100).rounded())
    }

    private func segmentHint(_ pkg: Package) -> String {
        switch pkg.packageType {
        case .annual:   return annualSavingsPercent.map { "Save \($0)%" } ?? "Popular"
        case .monthly:  return "Flexible"
        case .lifetime: return "Best Value"
        default:        return ""
        }
    }

    private func periodSuffix(_ pkg: Package) -> String {
        switch pkg.packageType {
        case .annual:   return "/ year"
        case .monthly:  return "/ month"
        case .lifetime: return "one-time"
        default:        return ""
        }
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
                .font(DS.tech(9.5))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.bottom, 14)
                .padding(.top, 28)

            VStack(spacing: 0) {
                ForEach(Array(features.enumerated()), id: \.offset) { idx, f in
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(DS.cyan.opacity(0.1))
                                .frame(width: 34, height: 34)
                            Image(systemName: f.icon)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(DS.cyan)
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
                            .foregroundStyle(DS.cyan)
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
                    .font(DS.tech(11))
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
                    vm.restorePurchases { success in
                        if success {
                            hasSeenPaywall = true
                            dismiss()
                        } else {
                            restoreMessage = "No active subscription found to restore. Please select a plan or ensure your Apple ID is correct."
                            showRestoreAlert = true
                        }
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
                Button("Privacy Policy") { safariURL = URL(string: "https://sites.google.com/view/inovexa/privacy-policy") }
                Text("•").foregroundStyle(.white.opacity(0.2))
                Button("Terms of Service") { safariURL = URL(string: "https://sites.google.com/view/inovexa/terms-and-conditions") }
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
