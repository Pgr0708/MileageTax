//
//  NotificationScreenView.swift
//  MileageTax
//

import SwiftUI

struct NotificationScreenView: View {
    @EnvironmentObject private var settings: SettingsManager

    var body: some View {
        AppTabView()
            .onAppear {
                settings.hasSeenNotificationPrompt = true
                settings.hasSeenCustomization = true
            }
    }
}
