//
//  RootView.swift
//  MileageTax
//

import SwiftUI

enum AppFlow {
    case splash, onboarding, paywall, customization, locked, home
}

struct RootView: View {
    @EnvironmentObject private var settings: SettingsManager
    @ObservedObject private var coreData = CoreDataManager.shared
    @AppStorage(AppStorageKeys.isPremium) private var isPremium = false

    /// Locked once onboarding is done, the free allowance is exhausted, and the
    /// user is not Pro. Reactive to both `isPremium` (UserDefaults) and the
    /// live trip counter (`completedTripCount`).
    private var isLocked: Bool {
        settings.hasSeenCustomization
            && !isPremium
            && coreData.completedTripCount >= MileageTaxDefaults.freeTripLimit
    }

    var currentFlow: AppFlow {
        if !settings.hasSeenOnboarding       { return .onboarding }

        // Onboarding paywall — skipped for existing subscribers, and only part
        // of onboarding (never re-triggered once customization is done).
        if !settings.hasSeenCustomization {
            if !settings.hasSeenPaywall && !isPremium { return .paywall }
            return .customization
        }

        if isLocked { return .locked }
        return .home
    }

    @ViewBuilder private var flowView: some View {
        switch currentFlow {
        case .onboarding:    OnBoardingScreenView()
        case .paywall:       PaywallScreenView()
        case .customization: CustomizationScreenView()
        case .locked:        PaywallScreenView(isForced: true)
        case .home:          AppTabView()
        default:             SplashScreenView()
        }
    }

    var body: some View {
        ZStack {
            // Each flow step slides in from the right while the old one zooms back and fades.
            flowView
                .id(currentFlow)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .scale(scale: 0.94).combined(with: .opacity)))
        }
        .animation(.spring(response: 0.55, dampingFraction: 0.86), value: currentFlow)
        .onAppear {
            CoreDataManager.shared.persistDefaultsToCloud()
            if isPremium { settings.hasSeenPaywall = true }
        }
        .onChange(of: currentFlow) { _, _ in CoreDataManager.shared.persistDefaultsToCloud() }
        .onChange(of: isPremium) { _, premium in
            if premium { settings.hasSeenPaywall = true }
        }
        .onChange(of: isLocked) { _, locked in
            if locked { TripTrackerService.shared.stop() }
        }
    }
}
