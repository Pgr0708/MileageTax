//
//  MileageTaxApp.swift
//  MileageTax
//
//  Created by Minaxi on 11/09/26.
//

import SwiftUI
import CoreData

struct Device {

    static var height: CGFloat {
        UIScreen.main.bounds.height
    }

    static var width: CGFloat {
        UIScreen.main.bounds.width
    }

    static var bottomSafeArea: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .safeAreaInsets.bottom ?? 0
    }

    static var topSafeArea: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .safeAreaInsets.top ?? 0
    }
}

    
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
