//
//  RootView.swift
//  MileageTax
//

import SwiftUI

enum AppFlow {
    case splash, language, onboarding, paywall, customization, locked, home
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
        if !settings.hasSeenLanguage         { return .language }
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

    var body: some View {
        Group {
            switch currentFlow {
            case .language:      LanguageScreenView()
            case .onboarding:    OnBoardingScreenView()
            case .paywall:       PaywallScreenView()
            case .customization: CustomizationScreenView()
            case .locked:        PaywallScreenView(isForced: true)
            case .home:          AppTabView()
            default:             SplashScreenView()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: currentFlow)
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
