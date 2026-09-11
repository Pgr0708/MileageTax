//
//  MileageTaxApp.swift
//  MileageTax
//
//  Created by Minaxi on 11/09/26.
//

import SwiftUI
import CoreData

@main
struct MileageTaxApp: App {
    @StateObject private var settings = SettingsManager()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                .environmentObject(settings)
                .environment(
                    \.locale,
                     Locale(identifier: settings.languageCode)
                     )
                .environment(
                           \.managedObjectContext,
                           CoreDataManager.shared.context
                       )
                .preferredColorScheme(settings.preferredColorScheme)
        }
    }
}
