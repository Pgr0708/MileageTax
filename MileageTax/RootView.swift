//
//  RootView.swift
//  MileageTax
//

import SwiftUI

enum AppFlow {
    case splash, language, onboarding, paywall, notification, customization, home
}

struct RootView: View {
    @EnvironmentObject private var settings: SettingsManager

    var currentFlow: AppFlow {
        if !settings.hasSeenLanguage         { return .language }
        if !settings.hasSeenOnboarding       { return .onboarding }
        if !settings.hasSeenPaywall          { return .paywall }
        if !settings.hasSeenNotificationPrompt { return .notification }
        if !settings.hasSeenCustomization    { return .customization }
        return .home
    }

    var body: some View {
        switch currentFlow {
        case .language:      LanguageScreenView()
        case .onboarding:    OnBoardingScreenView()
        case .paywall:       PaywallScreenView()
        case .notification:  NotificationScreenView()
        case .customization: CustomizationScreenView()
        case .home:          AppTabView()
        default:             SplashScreenView()
        }
    }
}
