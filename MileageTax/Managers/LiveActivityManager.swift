// LiveActivityManager.swift — MileageTax
// Wraps ActivityKit to push live mileage data to the Dynamic Island
// and Lock Screen while a trip is in progress.
//
// NOTE: The ActivityAttributes struct MUST match the one in the
//       widget extension target (MileageTaxLiveActivity).
//       Both files reference the same ActivityAttributes type via
//       a shared module; for a single-target build, just keep them in sync.

import Foundation
import ActivityKit
internal import Combine

// MARK: - Shared Attributes (also used by the Widget Extension)

public struct TripLiveActivityAttributes: ActivityAttributes {
    public typealias ContentState = TripLiveActivityContent

    public struct TripLiveActivityContent: Codable, Hashable {
        public var distanceMiles: Double
        public var speedMph:      Double
        public var deductionUSD:  Double
        public var elapsedSeconds: Int
        public var startAddress:  String
        public var statusLabel:   String    // e.g. "Active", "Idle Buffer"
    }

    public var tripID: String
    public var vehicleName: String

    public init(tripID: String, vehicleName: String) {
        self.tripID      = tripID
        self.vehicleName = vehicleName
    }
}

// MARK: - Manager

@MainActor
final class LiveActivityManager: ObservableObject {

    static let shared = LiveActivityManager()
    private var activity: Activity<TripLiveActivityAttributes>?

    private init() {}

    // MARK: - Start

    func startActivity(tripID: UUID,
                       vehicleName: String,
                       startAddress: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("🏝 LiveActivity: Activities disabled by user.")
            return
        }
        // Kill any stale activity first
        stopActivity()

        let attrs = TripLiveActivityAttributes(
            tripID:      tripID.uuidString,
            vehicleName: vehicleName)

        let initial = TripLiveActivityAttributes.TripLiveActivityContent(
            distanceMiles:  0,
            speedMph:       0,
            deductionUSD:   0,
            elapsedSeconds: 0,
            startAddress:   startAddress,
            statusLabel:    "Active")

        do {
            activity = try Activity.request(
                attributes: attrs,
                content:    ActivityContent(state: initial, staleDate: nil),
                pushType:   nil)
            print("🏝 LiveActivity started: \(activity?.id ?? "?")")
        } catch {
            print("🏝 LiveActivity ERROR: \(error.localizedDescription)")
        }
    }

    // MARK: - Update

    func update(miles: Double,
                speed: Double,
                deduction: Double,
                elapsed: Int,
                status: String) {
        guard let activity else { return }
        let content = TripLiveActivityAttributes.TripLiveActivityContent(
            distanceMiles:  miles,
            speedMph:       speed,
            deductionUSD:   deduction,
            elapsedSeconds: elapsed,
            startAddress:   "",
            statusLabel:    status)

        Task {
            await activity.update(
                ActivityContent(state: content, staleDate: nil))
        }
    }

    // MARK: - Stop

    func stopActivity() {
        guard let activity else { return }
        let final = activity.content.state
        Task {
            await activity.end(
                ActivityContent(state: final, staleDate: Date()),
                dismissalPolicy: .after(Date().addingTimeInterval(60)))
        }
        self.activity = nil
    }
}
