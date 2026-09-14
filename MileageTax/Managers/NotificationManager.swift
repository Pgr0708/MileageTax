// NotificationManager.swift — MileageTax
// Centralises all UNUserNotification logic:
//   • "Drive Started" — immediate banner
//   • "Drive Finished" — actionable: Classify Business / Personal / Skip
//   • "Weekly Summary" — scheduled every Sunday 9 AM
//   • "Needs-Review Reminder" — daily 8 PM if unclassified trips exist

import Foundation
import UserNotifications
import UIKit
import CoreData

final class NotificationManager: NSObject {

    static let shared = NotificationManager()

    // Action / Category identifiers
    static let categoryDriveFinished = "DRIVE_FINISHED"
    static let actionBusiness        = "ACTION_BUSINESS"
    static let actionPersonal        = "ACTION_PERSONAL"
    static let actionSkip            = "ACTION_SKIP"
    static let categoryWeeklySummary = "WEEKLY_SUMMARY"

    // UserInfo keys
    static let tripIDKey = "tripID"

    private override init() { super.init() }

    // MARK: - Setup

    func configure() {
        UNUserNotificationCenter.current().delegate = self
        registerCategories()
    }

    func requestAuthorisation() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge, .provisional])
        } catch {
            print("🔔 Notification auth error: \(error)")
            return false
        }
    }

    // MARK: - Actionable Categories

    private func registerCategories() {
        let businessAction = UNNotificationAction(
            identifier: Self.actionBusiness,
            title: "💼 Business",
            options: [.foreground])
        let personalAction = UNNotificationAction(
            identifier: Self.actionPersonal,
            title: "🏠 Personal",
            options: [.foreground])
        let skipAction = UNNotificationAction(
            identifier: Self.actionSkip,
            title: "Later",
            options: [.destructive])

        let driveCategory = UNNotificationCategory(
            identifier: Self.categoryDriveFinished,
            actions: [businessAction, personalAction, skipAction],
            intentIdentifiers: [],
            options: [.customDismissAction])

        let weeklyCategory = UNNotificationCategory(
            identifier: Self.categoryWeeklySummary,
            actions: [],
            intentIdentifiers: [],
            options: [])

        UNUserNotificationCenter.current()
            .setNotificationCategories([driveCategory, weeklyCategory])
    }

    // MARK: - Drive Started

    func sendDriveStarted(address: String) {
        let content = UNMutableNotificationContent()
        content.title    = "🚗 Drive Detected"
        content.subtitle = address
        content.body     = "MileageTax is tracking your mileage automatically."
        content.sound    = .default
        content.interruptionLevel = .timeSensitive

        let req = UNNotificationRequest(
            identifier: "drive_started_\(UUID().uuidString)",
            content: content,
            trigger: nil) // immediate
        UNUserNotificationCenter.current().add(req)
    }

    // MARK: - Drive Finished (Actionable)

    func sendDriveFinished(tripID: UUID, miles: Double, deduction: Double, address: String) {
        let content = UNMutableNotificationContent()
        content.title    = String(format: "✅ Drive Complete — %.1f mi", miles)
        content.subtitle = address
        content.body     = String(format: "Est. deduction: $%.2f · Tap to classify.", deduction)
        content.sound    = UNNotificationSound(named: UNNotificationSoundName("chime.aiff"))
        content.categoryIdentifier = Self.categoryDriveFinished
        content.interruptionLevel  = .active
        content.userInfo           = [Self.tripIDKey: tripID.uuidString]

        let req = UNNotificationRequest(
            identifier: "drive_finished_\(tripID.uuidString)",
            content: content,
            trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    // MARK: - Weekly Summary (Sunday 9 AM)

    func scheduleWeeklySummary() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["weekly_summary"])

        let content = UNMutableNotificationContent()
        content.title = "📊 Your Weekly Mileage Report"
        content.body  = "Open MileageTax to review this week's trips and maximise your deduction."
        content.sound = .default
        content.categoryIdentifier = Self.categoryWeeklySummary

        var dc = DateComponents()
        dc.weekday = 1  // Sunday
        dc.hour    = 9
        dc.minute  = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
        let req = UNNotificationRequest(
            identifier: "weekly_summary",
            content: content,
            trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    // MARK: - Needs-Review Reminder (8 PM daily if unclassified)

    func scheduleNeedsReviewReminder(count: Int) {
        guard count > 0 else {
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: ["needs_review"])
            return
        }

        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["needs_review"])

        let content = UNMutableNotificationContent()
        content.title = "📋 \(count) Trip\(count > 1 ? "s" : "") Need Classification"
        content.body  = "Classify now to lock in your tax deduction."
        content.sound = .default

        var dc = DateComponents()
        dc.hour   = 20
        dc.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
        let req = UNNotificationRequest(
            identifier: "needs_review",
            content: content,
            trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {

    // Show banners even when app is foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 willPresent notification: UNNotification,
                                 withCompletionHandler completionHandler:
                                 @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 didReceive response: UNNotificationResponse,
                                 withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo  = response.notification.request.content.userInfo
        let tripIDStr = userInfo[Self.tripIDKey] as? String ?? ""
        let tripID    = UUID(uuidString: tripIDStr)

        switch response.actionIdentifier {
        case Self.actionBusiness:
            classifyTrip(id: tripID, as: "business")
        case Self.actionPersonal:
            classifyTrip(id: tripID, as: "personal")
        case UNNotificationDefaultActionIdentifier:
            // User tapped banner — open classify screen
            NotificationCenter.default.post(
                name: .openClassifyForTrip,
                object: tripID)
        default:
            break
        }
        completionHandler()
    }

    // MARK: private helper

    private func classifyTrip(id: UUID?, as classification: String) {
        guard let id else { return }
        let ctx = CoreDataManager.shared.context
        let req = TripEntity.fetchRequest()
        req.predicate  = NSPredicate(format: "id == %@", id as CVarArg)
        req.fetchLimit = 1
        if let entity = try? ctx.fetch(req).first {
            entity.classification = classification
            entity.needsReview    = false
            CoreDataManager.shared.save()
        }
    }
}

// MARK: - Notification Name
extension Notification.Name {
    static let openClassifyForTrip = Notification.Name("MTOpenClassifyForTrip")
}
