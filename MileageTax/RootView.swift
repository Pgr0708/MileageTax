//
//  RootView.swift
//  MileageTax
//

import SwiftUI

enum AppFlow {
    case splash, language, onboarding, paywall, customization, home
}

struct RootView: View {
    @EnvironmentObject private var settings: SettingsManager

    var currentFlow: AppFlow {
        if !settings.hasSeenLanguage         { return .language }
        if !settings.hasSeenOnboarding       { return .onboarding }
        if !settings.hasSeenPaywall          { return .paywall }
        if !settings.hasSeenCustomization    { return .customization }
        return .home
    }

    var body: some View {
        Group {
            switch currentFlow {
            case .language:      LanguageScreenView()
            case .onboarding:    OnBoardingScreenView()
            case .paywall:       PaywallScreenView()
            case .customization: CustomizationScreenView()
            case .home:          AppTabView()
            default:             SplashScreenView()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: currentFlow)
        .onAppear { CoreDataManager.shared.persistDefaultsToCloud() }
        .onChange(of: currentFlow) { _, _ in CoreDataManager.shared.persistDefaultsToCloud() }
    }
}
