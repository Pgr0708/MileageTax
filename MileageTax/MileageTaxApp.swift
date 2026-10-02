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
    
    @Environment(\.scenePhase) var scenePhase
    @StateObject private var authManager = BiometricAuthManager.shared
    @AppStorage("MT_faceIDLockEnabled") private var faceIDLockEnabled = true
    
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let i = ProcessInfo.processInfo.arguments.firstIndex(of: "-artPage"),
               let page = Int(ProcessInfo.processInfo.arguments[safe: i + 1] ?? "") {
                ArtGalleryView(page: page)
            } else { appRoot }
            #else
            appRoot
            #endif
        }
    }

    private var appRoot: some View {
            ZStack {
                SplashScreenView()
                    .environmentObject(settings)
                    .environment(\.locale, Locale(identifier: settings.languageCode))
                    .environment(\.managedObjectContext, CoreDataManager.shared.context)
                    .preferredColorScheme(settings.preferredColorScheme)
                
                if faceIDLockEnabled && !authManager.isUnlocked {
                    LockScreenView()
                        .transition(.opacity)
                        .zIndex(2)
                }
            }
            .onChange(of: scenePhase) { newPhase in
                if faceIDLockEnabled {
                    if newPhase == .background {
                        authManager.lock()
                    }
                }
            }
    }
}

private extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
