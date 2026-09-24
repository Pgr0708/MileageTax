//
//  AppDelegate.swift
//  GoViral
//
//  Created by Minaxi on 16/08/26.
//

import Foundation
import Firebase
import FirebaseCore
import FirebaseMessaging
import UserNotifications
import RevenueCat
import CoreData

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: revenueCatAPIKey)
        Purchases.shared.delegate = self
        
        application.registerForRemoteNotifications()

        Messaging.messaging().token { token, error in
            if let error {
                print("Error fetching FCM registration token: \(error)")
            } else if let token {
                print("FCM registration token: \(token)")
            }
        }
        
        // 1. Register background tasks (BGTaskScheduler requires this BEFORE didFinishLaunching returns)
        TripTrackerService.registerBackgroundTasks()
        // 2. Pass launch options to the engine so it knows if iOS woke the app in the background
        TripTrackerAppLifecycle.handleLaunch(launchOptions: launchOptions)
        // 3. Configure local notification categories and delegate
        // 4. Backfill any trips missing reverse-geocoded addresses (one-time, async)
        Task {
            await CoreDataManager.shared.backfillMissingAddresses()
        }
        NotificationManager.shared.configure()
        NotificationManager.shared.scheduleWeeklySummary()
        
        return true
    }
    
    func application(_: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Oh no! Failed to register for remote notifications with error \(error)")
    }

    func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        var readableToken = ""
        for index in 0 ..< deviceToken.count {
            readableToken += String(format: "%02.2hhx", deviceToken[index] as CVarArg)
        }
        print("Received an APNs device token: \(readableToken)")
    }

    // CloudKit delivers silent pushes when the private database changes on
    // another device. Acknowledge them so the store coordinator can import.
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        completionHandler(.newData)
    }
}

extension AppDelegate: MessagingDelegate {
    @objc func messaging(_: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("Firebase token: \(String(describing: fcmToken))")
    }
}

extension AppDelegate : PurchasesDelegate {
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        BaseViewModel().checkUserIsPro(customerInfo: customerInfo)
    }
}
