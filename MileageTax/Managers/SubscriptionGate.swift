//
//  SubscriptionGate.swift
//  MileageTax — free-trip allowance → hard paywall gate
//
//  Single source of truth for "after N free trips, lock everything until Pro".
//

import Foundation

enum SubscriptionGate {

    static var isPremium: Bool {
        UserDefaults.standard.bool(forKey: AppStorageKeys.isPremium)
    }

    static var completedTrips: Int {
        CoreDataManager.shared.completedTripCount
    }

    /// True when the free allowance is exhausted and the user is not Pro.
    static var isLocked: Bool {
        !isPremium && completedTrips >= MileageTaxDefaults.freeTripLimit
    }

    static var tripsRemaining: Int {
        max(0, MileageTaxDefaults.freeTripLimit - completedTrips)
    }
}
