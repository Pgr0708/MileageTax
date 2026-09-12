//
//  TripIntelligenceEngine.swift
//  MileageTax
//
//  ────────────────────────────────────────────────────────────────────────
//  AUTONOMOUS AI MILEAGE & TAX WRITE-OFF DETECTION ENGINE  ("THE BRAIN")
//  ────────────────────────────────────────────────────────────────────────
//
//  100% native, zero third-party-dependency background drive detection
//  engine for iOS. Rebuilt from scratch using ONLY Apple frameworks
//  (CoreLocation, CoreMotion, BackgroundTasks, UserNotifications,
//  AVFoundation, CoreBluetooth) — zero SDK licensing costs.
//
//  ────────────────────────────────────────────────────────────────────────
//  FULL PATCH HISTORY — all 12 fixes applied in this file
//  ────────────────────────────────────────────────────────────────────────
//
//  FIX 1  — "Accuracy Gate Deadlock" in idleBuffer
//      enterIdleBuffer() relaxes desiredAccuracy to 100m to save battery,
//      causing incoming fixes to report ~35–70m horizontalAccuracy. The
//      old 25m gate discarded every fix while stopped, trapping the FSM
//      in idleBuffer until the 5-min hard timeout.
//      FIX: currentAccuracyGate() relaxes to 65m while state == .idleBuffer.
//
//  FIX 2  — Dead disambiguateWalkingVsVehicle never invoked
//      CoreMotion .walking can't distinguish a phone in a car from a
//      pedestrian. FIX: handleMotionActivity() now calls
//      disambiguateWalkingVsVehicle before trusting .walking in idleBuffer.
//      isDisambiguatingWalkingSignal prevents overlapping pedometer queries.
//
//  FIX 3  — Background suspension via unstructured Task
//      Task { @MainActor in } could be suspended before starting when the
//      screen locked. FIX: all delegate callbacks use
//      MainActor.assumeIsolated for synchronous in-window ingestion.
//
//  FIX 4  — CoreData I/O stutter every 5 breadcrumbs
//      Snapshot cadence throttled to every 30 breadcrumbs OR 60 seconds.
//      A lastPersistedAt timestamp tracks the time-based guard.
//
//  PATCH 1 — allowDeferredLocationUpdates silently rejected
//      Apple mandates distanceFilter == kCLDistanceFilterNone before calling
//      allowDeferredLocationUpdates. Elastic filters caused
//      CLError.deferredDistanceFilterInvalid — GPS never slept, wasting
//      1–2% battery/hr. FIX: background path sets kCLDistanceFilterNone
//      first; elastic filter restored in didFinishDeferredUpdatesWithError
//      and on the foreground path.
//
//  PATCH 2 — Stale timestamp divider in processVerification
//      verifyingMotionStartLocation could be stamped from the previous night.
//      On cold-start, GPS speed == -1 for ~15s, so displacement/elapsed
//      gave 0.005 m/s — far below the 6.7 m/s gate — losing the first mile.
//      FIX: verifyingMotionStartTime = Date() recorded in
//      beginMotionVerification; elapsed measured against that wall-clock time.
//
//  PATCH 3 — Pedestrian-tuned Kalman filter cuts highway corners
//      processNoiseMetersPerSecond = 3.0 over-damped rapid positional changes
//      on ramps, under-reporting odometer by 1.5–3.0%.
//      FIX: raised to 15.0 m/s (automotive scale).
//
//  FIX 5  — Cold-Start Crash Recovery dead code
//      After iOS kills and silently relaunches the app, inProgressRecord is
//      nil in RAM so resumeAnyInterruptedTripIfNeeded() returned immediately.
//      FIX: persistInProgressSnapshot() now writes a TripSnapshotData blob
//      to UserDefaults (key "com.mileagetax.inProgressSnapshot").
//      resumeAnyInterruptedTripIfNeeded() reads that key as a fallback before
//      the guard, reconstructing inProgressRecord from disk on cold boot.
//
//  FIX 6  — Accuracy Gate Trap during verifyingMotion
//      beginMotionVerification sets desiredAccuracy = kCLLocationAccuracyHundredMeters
//      but currentAccuracyGate() enforced the strict 25m ceiling during
//      .verifyingMotion — silently dropping every incoming fix and letting
//      the 40-second timer expire without ever starting a trip.
//      FIX: currentAccuracyGate() now returns the relaxed 65m gate for
//      both .idleBuffer AND .verifyingMotion.
//
//  FIX 7  — BGAppRefreshTask expiration handler bug
//      handleHeartbeat's expirationHandler called self?.endBackgroundTask(),
//      which ends UIBackgroundTaskIdentifiers — not BGAppRefreshTask. This
//      could prematurely kill an in-flight TripFinalize 30-second task.
//      FIX: expirationHandler now calls task.setTaskCompleted(success: false).
//
//  FIX 8  — Foreground/Background distance filter desync
//      distanceFilter remained kCLDistanceFilterNone (deferred-update mode)
//      when the user opened the app mid-drive, causing over-reporting.
//      FIX: UIApplication.willEnterForegroundNotification observer restores
//      the elastic distance filter immediately on foreground transition.
//
//  ────────────────────────────────────────────────────────────────────────
//  DROP-IN INTEGRATION (project uses CoreData, NOT SwiftData)
//  ─────────────────────────────────────────────────────────
//  1) File is already in the MileageTax target.
//  2) Info.plist — add:
//       NSLocationAlwaysAndWhenInUseUsageDescription
//       NSLocationTemporaryUsageDescriptionDictionary
//           key "PreciseMileageTracking"
//       NSMotionUsageDescription
//       NSBluetoothAlwaysUsageDescription  (optional)
//       UIBackgroundModes -> ["location", "processing", "fetch"]
//       BGTaskSchedulerPermittedIdentifiers -> ["com.mileagetax.heartbeat"]
//  3) Capabilities -> Background Modes:
//       ✅ Location updates  ✅ Background fetch  ✅ Background processing
//  4) In AppDelegate.application(_:didFinishLaunchingWithOptions:),
//     AFTER Firebase / RevenueCat boot:
//       TripTrackerService.registerBackgroundTasks()
//       TripTrackerAppLifecycle.handleLaunch(launchOptions: launchOptions)
//  5) SwiftUI binding:
//       @ObservedObject var tracker = TripTrackerService.shared
//       Text(tracker.liveBannerText)
//  ────────────────────────────────────────────────────────────────────────

import Foundation
import CoreLocation
import CoreMotion
import UserNotifications
import AVFoundation
import CoreBluetooth
import BackgroundTasks
import UIKit
import os
internal import Combine

// MARK: - Logging

nonisolated private let tripLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.mileagetax.app",
    category: "TripIntelligence"
)

// MARK: - Tunable Configuration

public enum TripTrackerConfig {

    // Layer 1 — Accuracy Gate
    static let maxAcceptableHorizontalAccuracyMeters: Double         = 25.0
    static let maxAcceptableHorizontalAccuracyLowPowerMeters: Double = 40.0
    /// FIX 1: relaxed to 65m while state == .idleBuffer. enterIdleBuffer sets
    /// desiredAccuracy = 100m; hardware responds with 35–70m fixes. Without
    /// this ceiling every fix is dropped and the FSM cannot observe acceleration.
    static let maxAcceptableHorizontalAccuracyIdleBufferMeters: Double = 65.0
    static let maxLocationAgeSeconds: TimeInterval = 15.0

    // Layer 2 — Stationary clamp
    static let minimumMovingSpeedMS: Double = 1.5          // ~3.35 mph

    // Layer 3 — Teleport / glitch filter
    static let maxPlausibleSpeedMS: Double = 49.1           // 110 mph

    // Extra — Heading plausibility (highway zig-zag rejection)
    static let maxCourseDeltaDegreesPerSecond: Double = 45.0
    static let courseCheckMinSpeedMS: Double           = 24.6 // ~55 mph

    // Layer 4 — Elastic distance filter
    static let cityDistanceFilterM: Double      = 10
    static let suburbanDistanceFilterM: Double  = 25
    static let highwayDistanceFilterM: Double   = 60
    static let citySpeedThresholdMS: Double     = 15.6  // 35 mph
    static let suburbanSpeedThresholdMS: Double = 24.6  // 55 mph

    // Layer 5 — Deferred updates
    /// PATCH 1: distanceFilter set to kCLDistanceFilterNone BEFORE calling
    /// allowDeferredLocationUpdates (mandatory Apple requirement).
    static let deferredDistanceMeters: CLLocationDistance = 200
    static let deferredTimeoutSeconds: TimeInterval       = 30

    // FSM thresholds
    static let stationaryGeofenceRadiusM: CLLocationDistance      = 50
    static let motionVerificationWindowSeconds: TimeInterval       = 40
    static let motionVerificationDisplacementM: CLLocationDistance = 150
    static let motionVerificationSpeedMS: Double                   = 6.7  // 15 mph
    static let idleBufferGraceSeconds: TimeInterval                = 300  // 5 min
    static let idleBufferMaxExtensionSeconds: TimeInterval         = 600  // ferry/drawbridge cap
    static let minimumTripDistanceMiles: Double                    = 0.5
    static let waypointStopMaxSeconds: TimeInterval                = 300
    static let tripMergeGapSeconds: TimeInterval                   = 180
    static let tripMergeDistanceMeters: CLLocationDistance         = 300
    static let staleInProgressTripHours: Double                    = 3.0
    static let idleBufferEntrySpeedMph: Double                     = 2.0
    static let idleBufferExitSpeedMph: Double                      = 10.0

    // Heartbeat
    static let heartbeatIntervalSeconds: TimeInterval        = 15 * 60
    static let motionStalenessThresholdSeconds: TimeInterval = 30 * 60

    // FIX 4 — Persistence throttle
    static let persistSnapshotEveryNBreadcrumbs: Int           = 30
    static let persistSnapshotMinIntervalSeconds: TimeInterval = 60
}

// MARK: - Tax Jurisdiction Rates

public struct TaxJurisdictionRate: Sendable {
    public let currencyCode: String
    public let ratePerMile: Double
    public static let usIRS2024 = TaxJurisdictionRate(currencyCode: "USD", ratePerMile: 0.67)
    public static let ukHMRC    = TaxJurisdictionRate(currencyCode: "GBP", ratePerMile: 0.45)
    public static let canadaCRA = TaxJurisdictionRate(currencyCode: "CAD", ratePerMile: 0.70 * 1.60934)
}

// MARK: - FSM State & Supporting Enums

public enum TripState: String, Sendable {
    case dormant, verifyingMotion, activeTracking, idleBuffer, tripFinalizing
}

private enum TripStartTrigger: String {
    case coreMotionAutomotive, geofenceExit, visitDeparture
}

public enum TripClassification: String, Codable, CaseIterable, Sendable {
    case business, personal, unclassified
    case needsReview = "needs_review"
}

// MARK: - Value Types

public struct TripBreadcrumb: Codable, Identifiable, Sendable {
    public var id:                    UUID   = UUID()
    public var latitude:              Double
    public var longitude:             Double
    public var timestamp:             Date
    public var speedMetersPerSecond:  Double
    public var courseDegrees:         Double
    public var horizontalAccuracy:    Double

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    public init(location: CLLocation) {
        latitude            = location.coordinate.latitude
        longitude           = location.coordinate.longitude
        timestamp           = location.timestamp
        speedMetersPerSecond = max(location.speed, 0)
        courseDegrees       = location.course
        horizontalAccuracy  = location.horizontalAccuracy
    }
}

public struct TripWaypoint: Codable, Identifiable, Sendable {
    public var id:        UUID   = UUID()
    public var latitude:  Double
    public var longitude: Double
    public var arrival:   Date
    public var departure: Date
    public var address:   String?
    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Crash-Recovery Snapshot (FIX 5)
// Lightweight Codable mirror of TripMemoryRecord persisted to UserDefaults.
// Only the fields needed to reconstruct an interrupted trip are stored —
// breadcrumbs and waypoints are included so the resumed track is complete.

public struct TripSnapshotData: Codable, Sendable {
    public var startDate:            Date
    public var updatedAt:            Date
    public var startLatitude:        Double
    public var startLongitude:       Double
    public var endLatitude:          Double
    public var endLongitude:         Double
    public var totalDistanceMiles:   Double
    public var maxSpeedMph:          Double
    public var taxDeductionValueUSD: Double
    public var breadcrumbs:          [TripBreadcrumb]
    public var waypoints:            [TripWaypoint]
    public var currencyCode:         String
}

// MARK: - In-Memory Trip Record
// Project uses CoreData (GoViral.xcdatamodeld), not SwiftData.
// TripMemoryRecord holds the active trip in RAM; hand off to CoreDataManager
// on finalisation. See "Persist to CoreData here" comments below.

public final class TripMemoryRecord {
    public var id:                    UUID   = UUID()
    public var startDate:             Date
    public var endDate:               Date
    public var startLatitude:         Double = 0
    public var startLongitude:        Double = 0
    public var endLatitude:           Double = 0
    public var endLongitude:          Double = 0
    public var startAddress:          String = "Resolving..."
    public var endAddress:            String = "In progress"
    public var totalDistanceMiles:    Double = 0
    public var maxSpeedMph:           Double = 0
    public var averageMovingSpeedMph: Double = 0
    public var taxDeductionValueUSD:  Double = 0
    public var classification:        TripClassification = .unclassified
    public var businessPurpose:       String?
    public var vehicleName:           String?
    public var breadcrumbs:           [TripBreadcrumb] = []
    public var waypoints:             [TripWaypoint]   = []
    public var isInProgress:          Bool   = true
    public var needsReview:           Bool   = false
    public var currencyCode:          String = "USD"
    public var createdAt:             Date   = Date()
    public var updatedAt:             Date   = Date()

    public init(startDate: Date, endDate: Date) {
        self.startDate = startDate
        self.endDate   = endDate
    }
    public var startCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: startLatitude, longitude: startLongitude)
    }
    public var endCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: endLatitude, longitude: endLongitude)
    }
}

// MARK: - Kalman-Filtered Position Smoothing
//
// Speed is ALWAYS read from CoreLocation's Doppler-derived location.speed —
// never from Kalman-smoothed positions — because Doppler is far more accurate
// and speed drives all FSM decisions.
//
// PATCH 3: processNoiseMetersPerSecond raised from 3.0 (walking) to 15.0
// (automotive). At 3.0 the filter over-damped ramp / sharp-turn geometry,
// cutting corners and under-reporting odometer by 1.5–3.0%.

final class KalmanLocationFilter {
    private var variance:  Double = -1
    private let minAccuracyMeters: Double = 1
    // PATCH 3: automotive-scale process noise (was 3.0 — pedestrian scale)
    private let processNoiseMetersPerSecond: Double = 15.0
    private(set) var latitude:  Double = 0
    private(set) var longitude: Double = 0
    private var timestampMs:    Double = 0

    func reset() { variance = -1 }

    @discardableResult
    func process(location: CLLocation) -> CLLocation {
        let accuracy = max(location.horizontalAccuracy, minAccuracyMeters)
        let timeMs   = location.timestamp.timeIntervalSince1970 * 1000

        if variance < 0 {
            timestampMs = timeMs
            latitude    = location.coordinate.latitude
            longitude   = location.coordinate.longitude
            variance    = accuracy * accuracy
        } else {
            let dtSeconds = max(0, (timeMs - timestampMs) / 1000)
            timestampMs   = timeMs
            variance += dtSeconds * processNoiseMetersPerSecond * processNoiseMetersPerSecond
            let gain   = variance / (variance + accuracy * accuracy)
            latitude  += gain * (location.coordinate.latitude  - latitude)
            longitude += gain * (location.coordinate.longitude - longitude)
            variance   = (1 - gain) * variance
        }

        return CLLocation(
            coordinate:         CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude:           location.altitude,
            horizontalAccuracy: location.horizontalAccuracy,
            verticalAccuracy:   location.verticalAccuracy,
            course:             location.course,
            speed:              location.speed,
            timestamp:          location.timestamp
        )
    }
}

// MARK: - Rate-Limited Cached Reverse Geocoder

actor GeocodeCache {
    static let shared = GeocodeCache()
    private var cache: [String: String] = [:]
    private let geocoder = CLGeocoder()
    private var lastRequestAt: Date = .distantPast
    private let minRequestInterval: TimeInterval = 1.0

    func address(for location: CLLocation) async -> String {
        let key = Self.key(for: location.coordinate)
        if let cached = cache[key] { return cached }

        let elapsed = Date().timeIntervalSince(lastRequestAt)
        if elapsed < minRequestInterval {
            let delayNs = UInt64((minRequestInterval - elapsed) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: delayNs)
        }
        lastRequestAt = Date()

        do {
            let placemarks = try await withCheckedThrowingContinuation {
                (c: CheckedContinuation<[CLPlacemark], Error>) in
                geocoder.reverseGeocodeLocation(location) { p, e in
                    if let e { c.resume(throwing: e) } else { c.resume(returning: p ?? []) }
                }
            }
            if let p = placemarks.first {
                let result = Self.format(placemark: p)
                cache[key] = result
                return result
            }
        } catch {
            tripLogger.debug("Geocode failed: \(error.localizedDescription, privacy: .public)")
        }
        let fallback = String(format: "%.5f, %.5f",
                              location.coordinate.latitude, location.coordinate.longitude)
        cache[key] = fallback
        return fallback
    }

    private static func key(for c: CLLocationCoordinate2D) -> String {
        String(format: "%.4f,%.4f", c.latitude, c.longitude)
    }
    private static func format(placemark p: CLPlacemark) -> String {
        var parts: [String] = []
        if let s = p.subThoroughfare    { parts.append(s) }
        if let r = p.thoroughfare       { parts.append(r) }
        if let c = p.locality           { parts.append(c) }
        if let a = p.administrativeArea { parts.append(a) }
        return parts.isEmpty ? (p.name ?? "Unknown Location") : parts.joined(separator: " ")
    }
}

// MARK: - Vehicle Profile

public struct VehicleProfile: Codable, Identifiable, Sendable {
    public var id:            UUID   = UUID()
    public var bluetoothName: String
    public var displayName:   String
}

// MARK: - App Relaunch Helper

public enum TripTrackerAppLifecycle {
    @MainActor
    public static func handleLaunch(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        if launchOptions?[.location] != nil {
            tripLogger.notice("App silently relaunched by iOS via background location event.")
        }
        _ = TripTrackerService.shared
        TripTrackerService.shared.resumeAnyInterruptedTripIfNeeded()
        TripTrackerService.shared.start()
    }
}

// MARK: - The Engine

@MainActor
final class TripTrackerService: NSObject, ObservableObject {

    static let shared              = TripTrackerService()
    static let heartbeatTaskIdentifier = "com.mileagetax.heartbeat"
    nonisolated private static let stationaryRegionId = "com.mileagetax.stationaryGeofence"

    // MARK: Published state

    @Published private(set) var state:               TripState    = .dormant
    @Published private(set) var liveDistanceMiles:   Double       = 0
    @Published private(set) var liveDeductionUSD:    Double       = 0
    @Published private(set) var liveDurationSeconds: TimeInterval = 0
    @Published private(set) var currentSpeedMph:     Double       = 0
    @Published private(set) var isInsideVerifiedVehicle: Bool     = false
    @Published private(set) var connectedAudioDeviceName: String?
    @Published private(set) var lastCompletedTrip:   TripMemoryRecord?
    @Published private(set) var authorizationIssue:  String?

    var liveBannerText: String {
        switch state {
        case .activeTracking, .idleBuffer:
            return String(format: "🚗 Tracking Drive... %.1f mi · $%.2f",
                          liveDistanceMiles, liveDeductionUSD)
        case .verifyingMotion:  return "📡 Confirming motion..."
        case .tripFinalizing:   return "💾 Saving trip..."
        case .dormant:          return "🅿️ Parked"
        }
    }

    var rate: TaxJurisdictionRate = .usIRS2024
    var knownVehicles: [VehicleProfile] = []

    // MARK: Core managers

    private let locationManager       = CLLocationManager()
    private let motionActivityManager = CMMotionActivityManager()
    private let pedometer             = CMPedometer()
    private var bluetoothCentral:     CBCentralManager?
    private let kalmanFilter          = KalmanLocationFilter()

    // MARK: Trip-scoped state

    private var breadcrumbs:           [TripBreadcrumb] = []
    private var waypoints:             [TripWaypoint]   = []
    private var lastValidLocation:     CLLocation?
    private var lastKnownAnyLocation:  CLLocation?
    private var accumulatedMeters:     Double = 0
    private var speedSamples:          [Double] = []
    private var maxObservedSpeedMps:   Double   = 0
    private var tripStartDate:         Date?
    private var tripStartLocation:     CLLocation?
    private var inProgressRecord:      TripMemoryRecord?
    private var pendingWaypointStart:  CLLocation?

    // Verification state
    private var verifyingMotionStartLocation: CLLocation?
    private var verifyingMotionDeadline:      Date?
    private var verifyingMotionWorkItem:      DispatchWorkItem?
    private var activeTripStartTrigger:       TripStartTrigger?
    /// PATCH 2: fresh wall-clock timestamp recorded when verification begins.
    private var verifyingMotionStartTime:     Date?

    // Idle buffer state
    private var idleBufferStartDate:       Date?
    private var idleBufferAnchorLocation:  CLLocation?
    private var idleBufferWorkItem:        DispatchWorkItem?
    private var idleBufferExtensionCount:  Int = 0
    /// FIX 2: prevents overlapping async pedometer queries.
    private var isDisambiguatingWalkingSignal = false

    private var lastMotionActivity:        CMMotionActivity?
    private var motionCoprocessorAvailable = true
    private var stationaryRegion:          CLCircularRegion?
    private var backgroundTaskID:          UIBackgroundTaskIdentifier = .invalid

    private var lastFinalizedTrip:         TripMemoryRecord?
    private var lastFinalizedEndLocation:  CLLocation?

    /// FIX 4: tracks time of last persistence snapshot.
    private var lastPersistedAt: Date = .distantPast

    // MARK: Init

    private override init() {
        super.init()
        configureLocationManager()
        bluetoothCentral = CBCentralManager(
            delegate: self, queue: nil,
            options: [CBCentralManagerOptionShowPowerAlertKey: false])
        UNUserNotificationCenter.current().delegate = self
        registerNotificationCategories()
        observeAudioRouteChanges()
    }

    // MARK: - Public API

    func setKnownVehicles(_ vehicles: [VehicleProfile]) { knownVehicles = vehicles }

    func start() {
        requestPermissions()
        startMonitoringMotionActivity()
        locationManager.startMonitoringSignificantLocationChanges()
        if CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) {
            locationManager.startMonitoringVisits()
        }
        if let last = lastKnownAnyLocation ?? lastValidLocation {
            rearmStationaryGeofence(at: last.coordinate)
        } else {
            locationManager.requestLocation()
        }
        scheduleNextHeartbeat()
    }

    func stop() {
        motionActivityManager.stopActivityUpdates()
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
        locationManager.stopMonitoringVisits()
        if let r = stationaryRegion { locationManager.stopMonitoring(for: r) }
        idleBufferWorkItem?.cancel()
        verifyingMotionWorkItem?.cancel()
        transition(to: .dormant)
    }

    func resumeAnyInterruptedTripIfNeeded() {
        // FIX 5: On a cold-start (iOS killed + silently relaunched the app),
        // inProgressRecord is nil in RAM. Fall back to the lightweight JSON
        // snapshot written to UserDefaults by persistInProgressSnapshot().
        if inProgressRecord == nil {
            if let data = UserDefaults.standard.data(forKey: TripTrackerService.snapshotDefaultsKey),
               let saved = try? JSONDecoder().decode(TripSnapshotData.self, from: data) {
                tripLogger.notice("Cold-start: reconstructing inProgressRecord from UserDefaults snapshot.")
                let r = TripMemoryRecord(startDate: saved.startDate, endDate: saved.updatedAt)
                r.startLatitude         = saved.startLatitude
                r.startLongitude        = saved.startLongitude
                r.endLatitude           = saved.endLatitude
                r.endLongitude          = saved.endLongitude
                r.totalDistanceMiles    = saved.totalDistanceMiles
                r.maxSpeedMph           = saved.maxSpeedMph
                r.taxDeductionValueUSD  = saved.taxDeductionValueUSD
                r.breadcrumbs           = saved.breadcrumbs
                r.waypoints             = saved.waypoints
                r.isInProgress          = true
                r.currencyCode          = saved.currencyCode
                r.updatedAt             = saved.updatedAt
                inProgressRecord = r
            }
        }

        guard let record = inProgressRecord else { return }

        if Date().timeIntervalSince(record.updatedAt) > TripTrackerConfig.staleInProgressTripHours * 3600 {
            record.endDate      = record.updatedAt
            record.isInProgress = false
            record.needsReview  = true
            record.totalDistanceMiles = (record.totalDistanceMiles * 10).rounded() / 10
            // Stale trip — remove the on-disk snapshot so it doesn't resurface.
            UserDefaults.standard.removeObject(forKey: TripTrackerService.snapshotDefaultsKey)
            tripLogger.notice("Auto-closed stale in-progress trip.")
            return
        }
        tripStartDate     = record.startDate
        tripStartLocation = CLLocation(latitude: record.startLatitude, longitude: record.startLongitude)
        breadcrumbs       = record.breadcrumbs
        waypoints         = record.waypoints
        accumulatedMeters = record.totalDistanceMiles / 0.000621371
        if let last = breadcrumbs.last {
            lastValidLocation = CLLocation(latitude: last.latitude, longitude: last.longitude)
        }
        transition(to: .activeTracking)
        locationManager.activityType              = .automotiveNavigation
        locationManager.desiredAccuracy           = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter            = TripTrackerConfig.cityDistanceFilterM
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.allowsBackgroundLocationUpdates    = true
        locationManager.startUpdatingLocation()
        tripLogger.notice("Resumed interrupted trip.")
    }

    static func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: heartbeatTaskIdentifier, using: nil
        ) { task in
            guard let t = task as? BGAppRefreshTask else { return }
            Task { @MainActor in TripTrackerService.shared.handleHeartbeat(task: t) }
        }
    }

    func classify(tripId: UUID, as classification: TripClassification,
                  businessPurpose: String? = nil) {
        guard let record = inProgressRecord, record.id == tripId else { return }
        record.classification = classification
        if let bp = businessPurpose { record.businessPurpose = bp }
        // CoreDataManager.shared.saveTripRecord(record)
        tripLogger.debug("Trip \(tripId) → \(classification.rawValue, privacy: .public)")
    }

    // MARK: - Permissions

    private func requestPermissions() {
        switch locationManager.authorizationStatus {
        case .notDetermined:      locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse: locationManager.requestAlwaysAuthorization()
        default: break
        }
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                tripLogger.debug("Notification auth granted: \(granted)")
            }
    }

    private func evaluateAuthorizationStatus() {
        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            authorizationIssue = "Location access is off. Enable 'Always' in Settings."
        case .authorizedWhenInUse:
            authorizationIssue = "Upgrade to 'Always Allow' so trips are captured in the background."
            locationManager.requestAlwaysAuthorization()
        case .authorizedAlways:
            authorizationIssue = nil
            if locationManager.accuracyAuthorization == .reducedAccuracy {
                locationManager.requestTemporaryFullAccuracyAuthorization(
                    withPurposeKey: "PreciseMileageTracking")
            }
        case .notDetermined: break
        @unknown default: break
        }
    }

    // MARK: - Location Manager Setup

    private func configureLocationManager() {
        locationManager.delegate   = self
        locationManager.activityType    = .otherNavigation
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter  = 50
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.allowsBackgroundLocationUpdates    = true
        locationManager.showsBackgroundLocationIndicator   = true
    }

    /// FIX 1 + FIX 6: Layer-1 accuracy gate relaxed to 65m while idleBuffer
    /// OR verifyingMotion. beginMotionVerification sets desiredAccuracy =
    /// kCLLocationAccuracyHundredMeters (100m); hardware returns 35–75m fixes.
    /// Without the relaxed ceiling every fix during verification is silently
    /// dropped and the 40-second timer expires without ever starting a trip.
    private func currentAccuracyGate() -> Double {
        if state == .idleBuffer || state == .verifyingMotion {
            return TripTrackerConfig.maxAcceptableHorizontalAccuracyIdleBufferMeters
        }
        return ProcessInfo.processInfo.isLowPowerModeEnabled
            ? TripTrackerConfig.maxAcceptableHorizontalAccuracyLowPowerMeters
            : TripTrackerConfig.maxAcceptableHorizontalAccuracyMeters
    }

    private func elasticDistanceFilter(forSpeedMps s: Double) -> Double {
        if s < TripTrackerConfig.citySpeedThresholdMS     { return TripTrackerConfig.cityDistanceFilterM }
        if s < TripTrackerConfig.suburbanSpeedThresholdMS { return TripTrackerConfig.suburbanDistanceFilterM }
        return TripTrackerConfig.highwayDistanceFilterM
    }

    // MARK: - FSM

    private func transition(to newState: TripState) {
        tripLogger.debug("FSM \(self.state.rawValue, privacy: .public) -> \(newState.rawValue, privacy: .public)")
        state = newState
    }

    // MARK: - CoreMotion

    private func startMonitoringMotionActivity() {
        guard CMMotionActivityManager.isActivityAvailable() else {
            motionCoprocessorAvailable = false
            tripLogger.notice("Motion coprocessor unavailable — GPS-only FSM.")
            return
        }
        motionCoprocessorAvailable = true
        motionActivityManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self, let activity else { return }
            self.handleMotionActivity(activity)
        }
    }

    /// FIX 2: .walking while idleBuffer routed to pedometer disambiguation.
    private func handleMotionActivity(_ activity: CMMotionActivity) {
        lastMotionActivity = activity

        switch state {
        case .dormant:
            if activity.automotive && activity.confidence != .low {
                beginMotionVerification(trigger: .coreMotionAutomotive)
            }
        case .idleBuffer:
            if activity.automotive && activity.confidence != .low {
                cancelIdleBufferAndResumeActive()
            } else if activity.walking && activity.confidence == .high {
                guard !isDisambiguatingWalkingSignal else { return }
                isDisambiguatingWalkingSignal = true
                disambiguateWalkingVsVehicle(observedSpeedMph: currentSpeedMph) { [weak self] inVehicle in
                    guard let self else { return }
                    self.isDisambiguatingWalkingSignal = false
                    guard self.state == .idleBuffer else { return }
                    if inVehicle {
                        tripLogger.debug("Pedometer: ~0 steps at speed — gridlock. Resuming active.")
                        self.cancelIdleBufferAndResumeActive()
                    } else {
                        self.evaluateIdleBufferMotionSignal()
                    }
                }
            } else if activity.stationary && activity.confidence == .high {
                evaluateIdleBufferMotionSignal()
            }
        default: break
        }
    }

    private func disambiguateWalkingVsVehicle(observedSpeedMph: Double,
                                               completion: @escaping (Bool) -> Void) {
        guard CMPedometer.isStepCountingAvailable(), observedSpeedMph > 2.5 else {
            completion(false); return
        }
        let start = Date().addingTimeInterval(-20)
        pedometer.queryPedometerData(from: start, to: Date()) { data, _ in
            let steps = data?.numberOfSteps.intValue ?? 0
            DispatchQueue.main.async { completion(steps < 3) }
        }
    }

    // MARK: - Audio Route (Layer 7)

    private func observeAudioRouteChanges() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification, object: nil)
        // FIX 8: Restore elastic distance filter immediately when the user
        // brings the app to the foreground while a trip is active. Without
        // this, distanceFilter can remain kCLDistanceFilterNone (set by the
        // deferred-updates background path) until the next GPS update fires.
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification, object: nil)
        evaluateCurrentAudioRoute()
    }

    @objc private func handleWillEnterForeground() {
        // Restore the elastic distance filter so the foreground path
        // receives timely GPS updates at the correct granularity.
        guard state == .activeTracking || state == .idleBuffer else { return }
        let speedMps = lastValidLocation?.speed ?? 0
        locationManager.distanceFilter = elasticDistanceFilter(forSpeedMps: max(0, speedMps))
        tripLogger.debug("Foreground: restored elastic distanceFilter for speed \(speedMps, privacy: .public) m/s")
    }

    @objc private func handleRouteChange(_ note: Notification) {
        Task { @MainActor in self.evaluateCurrentAudioRoute() }
    }

    private func evaluateCurrentAudioRoute() {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        let vehiclePorts: Set<AVAudioSession.Port> = [.carAudio, .bluetoothHFP, .bluetoothA2DP, .bluetoothLE]
        guard let matched = outputs.first(where: { vehiclePorts.contains($0.portType) }) else {
            isInsideVerifiedVehicle  = false
            connectedAudioDeviceName = nil
            return
        }
        let name    = matched.portName
        let isKnown = knownVehicles.isEmpty || knownVehicles.contains { $0.bluetoothName == name }
        isInsideVerifiedVehicle  = matched.portType == .carAudio || isKnown
        connectedAudioDeviceName = name
    }

    // MARK: - Stationary Geofence

    private func rearmStationaryGeofence(at coordinate: CLLocationCoordinate2D) {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }
        if let r = stationaryRegion { locationManager.stopMonitoring(for: r) }
        let region = CLCircularRegion(
            center: coordinate, radius: TripTrackerConfig.stationaryGeofenceRadiusM,
            identifier: Self.stationaryRegionId)
        region.notifyOnEntry = false
        region.notifyOnExit  = true
        stationaryRegion     = region
        locationManager.startMonitoring(for: region)
        locationManager.stopUpdatingLocation()
    }

    // MARK: - Motion Verification

    /// PATCH 2: records a fresh Date() so processVerification doesn't divide
    /// displacement by an overnight-old seed location timestamp.
    private func beginMotionVerification(trigger: TripStartTrigger) {
        guard state == .dormant else { return }
        activeTripStartTrigger       = trigger
        verifyingMotionStartTime     = Date()       // PATCH 2
        verifyingMotionStartLocation = lastKnownAnyLocation
        verifyingMotionDeadline      = Date().addingTimeInterval(TripTrackerConfig.motionVerificationWindowSeconds)
        transition(to: .verifyingMotion)
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter  = 20
        locationManager.startUpdatingLocation()
        verifyingMotionWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.handleVerificationTimeout() }
        verifyingMotionWorkItem = item
        DispatchQueue.main.asyncAfter(
            deadline: .now() + TripTrackerConfig.motionVerificationWindowSeconds, execute: item)
    }

    private func handleVerificationTimeout() {
        guard state == .verifyingMotion else { return }
        tripLogger.debug("Verification timeout — false positive, reverting to dormant.")
        revertToDormant()
    }

    private func revertToDormant() {
        verifyingMotionWorkItem?.cancel()
        verifyingMotionStartLocation = nil
        verifyingMotionStartTime     = nil
        if let last = lastKnownAnyLocation { rearmStationaryGeofence(at: last.coordinate) }
        else                               { locationManager.stopUpdatingLocation() }
        transition(to: .dormant)
    }

    private func processVerification(location: CLLocation) {
        guard let seed = verifyingMotionStartLocation else {
            verifyingMotionStartLocation = location; return
        }
        let displacement = location.distance(from: seed)
        // PATCH 2: use wall-clock time, not seed.timestamp (which may be hours old).
        let elapsed  = max(0.5, Date().timeIntervalSince(verifyingMotionStartTime ?? Date()))
        let speedMps = location.speed >= 0 ? location.speed : (displacement / elapsed)

        if displacement > TripTrackerConfig.motionVerificationDisplacementM
            && speedMps > TripTrackerConfig.motionVerificationSpeedMS {
            promoteToActiveTracking(seedLocation: seed, confirmingLocation: location)
        } else if let deadline = verifyingMotionDeadline, Date() > deadline {
            handleVerificationTimeout()
        }
    }

    // MARK: - Promote to Active Tracking

    private func promoteToActiveTracking(seedLocation: CLLocation,
                                          confirmingLocation: CLLocation) {
        verifyingMotionWorkItem?.cancel()
        verifyingMotionStartTime = nil
        transition(to: .activeTracking)
        kalmanFilter.reset()

        // Trip merge check
        if let lastTrip = lastFinalizedTrip,
           let lastEnd  = lastFinalizedEndLocation,
           Date().timeIntervalSince(lastTrip.endDate) < TripTrackerConfig.tripMergeGapSeconds,
           seedLocation.distance(from: lastEnd) < TripTrackerConfig.tripMergeDistanceMeters {
            tripLogger.debug("Merging with recent trip.")
            tripStartDate       = lastTrip.startDate
            tripStartLocation   = CLLocation(latitude: lastTrip.startLatitude, longitude: lastTrip.startLongitude)
            breadcrumbs         = lastTrip.breadcrumbs
            waypoints           = lastTrip.waypoints
            accumulatedMeters   = lastTrip.totalDistanceMiles / 0.000621371
            speedSamples        = []
            maxObservedSpeedMps = lastTrip.maxSpeedMph / 2.23694
            inProgressRecord    = lastTrip
            lastTrip.isInProgress    = true
            lastFinalizedTrip        = nil
            lastFinalizedEndLocation = nil
        } else {
            tripStartDate       = seedLocation.timestamp
            tripStartLocation   = seedLocation
            breadcrumbs         = [TripBreadcrumb(location: seedLocation)]
            waypoints           = []
            accumulatedMeters   = 0
            speedSamples        = []
            maxObservedSpeedMps = 0
            inProgressRecord    = nil
        }

        lastValidLocation = seedLocation
        appendBreadcrumb(confirmingLocation)

        if let r = stationaryRegion { locationManager.stopMonitoring(for: r) }
        locationManager.activityType              = .automotiveNavigation
        locationManager.desiredAccuracy           = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter            = TripTrackerConfig.cityDistanceFilterM
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.allowsBackgroundLocationUpdates    = true
        locationManager.startUpdatingLocation()
        // NOTE: Do NOT call beginBackgroundTask() here.
        // UIBackgroundModes: location keeps the process alive while driving.
        // The 30-second background task budget is reserved for finalize/geocode.
    }

    // MARK: - 7-Layer Ingestion Pipeline

    private func ingest(location raw: CLLocation) {
        // LAYER 1 — Accuracy gate (FIX 1: 65m while idleBuffer)
        guard raw.horizontalAccuracy >= 0,
              raw.horizontalAccuracy <= currentAccuracyGate() else { return }
        // Stale fix guard
        guard -raw.timestamp.timeIntervalSinceNow < TripTrackerConfig.maxLocationAgeSeconds else { return }
        // PATCH 3: Kalman filter uses 15.0 m/s process noise (automotive scale)
        let location = kalmanFilter.process(location: raw)
        lastKnownAnyLocation = raw

        switch state {
        case .dormant:                     return
        case .verifyingMotion:             processVerification(location: location)
        case .activeTracking, .idleBuffer: processActiveOrIdle(location: location)
        case .tripFinalizing:              return
        }
    }

    private func processActiveOrIdle(location: CLLocation) {
        guard let last = lastValidLocation else {
            lastValidLocation = location
            appendBreadcrumb(location)
            return
        }
        let timeDelta = location.timestamp.timeIntervalSince(last.timestamp)
        guard timeDelta > 0.1 else { return }
        let distanceDelta    = location.distance(from: last)
        let computedVelocity = distanceDelta / timeDelta

        // LAYER 3 — Teleport filter
        guard computedVelocity < TripTrackerConfig.maxPlausibleSpeedMS else { return }

        // EXTRA — heading plausibility
        if computedVelocity > TripTrackerConfig.courseCheckMinSpeedMS,
           last.course >= 0, location.course >= 0 {
            var delta = abs(location.course - last.course)
            if delta > 180 { delta = 360 - delta }
            if delta > max(TripTrackerConfig.maxCourseDeltaDegreesPerSecond * timeDelta, 90) { return }
        }

        let speedMps        = location.speed >= 0 ? location.speed : computedVelocity
        currentSpeedMph     = speedMps * 2.23694
        maxObservedSpeedMps = max(maxObservedSpeedMps, speedMps)
        speedSamples.append(speedMps)

        // LAYER 2 — Stationary clamp
        if speedMps > TripTrackerConfig.minimumMovingSpeedMS {
            accumulatedMeters += distanceDelta
            liveDistanceMiles  = accumulatedMeters * 0.000621371
            liveDeductionUSD   = liveDistanceMiles * rate.ratePerMile
        }

        lastValidLocation = location
        appendBreadcrumb(location)

        // ──────────────────────────────────────────────────────────────────
        // LAYERS 4 & 5 — Elastic filter + deferred updates
        //
        // PATCH 1: Apple mandates distanceFilter == kCLDistanceFilterNone
        // before calling allowDeferredLocationUpdates. Elastic filter first
        // → CLError.deferredDistanceFilterInvalid → GPS never sleeps →
        // 1–2% extra battery/hr.
        //
        // Background: set kCLDistanceFilterNone, then defer.
        // Foreground:  set elastic filter normally.
        // After batch: restore elastic filter (see didFinishDeferredUpdates).
        // ──────────────────────────────────────────────────────────────────
        if CLLocationManager.deferredLocationUpdatesAvailable(),
           UIApplication.shared.applicationState == .background {
            locationManager.distanceFilter = kCLDistanceFilterNone   // PATCH 1
            locationManager.allowDeferredLocationUpdates(
                untilTraveled: TripTrackerConfig.deferredDistanceMeters,
                timeout:       TripTrackerConfig.deferredTimeoutSeconds)
        } else {
            locationManager.distanceFilter = elasticDistanceFilter(forSpeedMps: speedMps)
        }

        locationManager.desiredAccuracy = ProcessInfo.processInfo.isLowPowerModeEnabled
            ? TripTrackerConfig.maxAcceptableHorizontalAccuracyLowPowerMeters
            : kCLLocationAccuracyBestForNavigation

        liveDurationSeconds = Date().timeIntervalSince(tripStartDate ?? Date())

        // FSM speed transitions
        if state == .activeTracking, currentSpeedMph < TripTrackerConfig.idleBufferEntrySpeedMph {
            enterIdleBuffer(anchor: location)
        } else if state == .idleBuffer, currentSpeedMph > TripTrackerConfig.idleBufferExitSpeedMph {
            cancelIdleBufferAndResumeActive()
        }
    }

    /// FIX 4: throttle snapshot to every 30 breadcrumbs OR 60 seconds.
    private func appendBreadcrumb(_ location: CLLocation) {
        breadcrumbs.append(TripBreadcrumb(location: location))
        let byCount = breadcrumbs.count % TripTrackerConfig.persistSnapshotEveryNBreadcrumbs == 0
        let byTime  = Date().timeIntervalSince(lastPersistedAt) >= TripTrackerConfig.persistSnapshotMinIntervalSeconds
        if byCount || byTime { persistInProgressSnapshot() }
    }

    // MARK: - Idle Buffer

    private func enterIdleBuffer(anchor: CLLocation) {
        guard state == .activeTracking else { return }
        transition(to: .idleBuffer)
        idleBufferStartDate      = Date()
        idleBufferAnchorLocation = anchor
        idleBufferExtensionCount = 0
        pendingWaypointStart     = anchor
        // FIX 1 counterpart: currentAccuracyGate() now accepts the looser
        // fixes (up to 65m) that this intentional accuracy relaxation produces.
        locationManager.distanceFilter  = 15
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        scheduleIdleBufferTimeout()
    }

    private func scheduleIdleBufferTimeout() {
        idleBufferWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.evaluateIdleBufferMotionSignal(forceFinalize: true)
        }
        idleBufferWorkItem = item
        DispatchQueue.main.asyncAfter(
            deadline: .now() + TripTrackerConfig.idleBufferGraceSeconds, execute: item)
    }

    private func evaluateIdleBufferMotionSignal(forceFinalize: Bool = false) {
        guard state == .idleBuffer, let start = idleBufferStartDate else { return }
        let elapsed = Date().timeIntervalSince(start)
        guard elapsed >= TripTrackerConfig.idleBufferGraceSeconds || forceFinalize else { return }

        // Drawbridge / ferry guard: extend once if CoreMotion still says automotive
        if let a = lastMotionActivity, a.automotive, a.confidence != .low,
           elapsed < TripTrackerConfig.idleBufferMaxExtensionSeconds,
           idleBufferExtensionCount < 1 {
            tripLogger.debug("Idle buffer expired but still automotive — extending once.")
            idleBufferExtensionCount += 1
            scheduleIdleBufferTimeout()
            return
        }
        finalizeTrip()
    }

    private func cancelIdleBufferAndResumeActive() {
        guard state == .idleBuffer else { return }
        idleBufferWorkItem?.cancel()
        idleBufferWorkItem = nil

        if let start = idleBufferStartDate, let anchor = idleBufferAnchorLocation {
            let paused = Date().timeIntervalSince(start)
            if paused < TripTrackerConfig.waypointStopMaxSeconds {
                Task {
                    let address = await GeocodeCache.shared.address(for: anchor)
                    await MainActor.run {
                        self.waypoints.append(TripWaypoint(
                            latitude:  anchor.coordinate.latitude,
                            longitude: anchor.coordinate.longitude,
                            arrival:   start,
                            departure: Date(),
                            address:   address))
                    }
                }
            }
        }
        idleBufferStartDate      = nil
        idleBufferAnchorLocation = nil
        idleBufferExtensionCount = 0
        transition(to: .activeTracking)
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter  = elasticDistanceFilter(forSpeedMps: lastValidLocation?.speed ?? 0)
    }

    // MARK: - Trip Finalization

    private func finalizeTrip() {
        guard state == .idleBuffer || state == .activeTracking else { return }
        transition(to: .tripFinalizing)
        beginBackgroundTask()   // 30s window: geocode + save

        let cropDate         = idleBufferStartDate ?? Date()
        let cropped          = breadcrumbs.filter { $0.timestamp <= cropDate }
        let finalBreadcrumbs = cropped.isEmpty ? breadcrumbs : cropped

        guard let startLoc = tripStartLocation,
              let endCrumb = finalBreadcrumbs.last else {
            discardAndReset(rearmAt: lastValidLocation?.coordinate ?? lastKnownAnyLocation?.coordinate)
            return
        }
        let endLocation   = CLLocation(latitude: endCrumb.latitude, longitude: endCrumb.longitude)
        let distanceMiles = accumulatedMeters * 0.000621371

        guard distanceMiles >= TripTrackerConfig.minimumTripDistanceMiles else {
            tripLogger.debug("Trip discarded — \(distanceMiles) mi < 0.5mi minimum.")
            discardAndReset(rearmAt: endLocation.coordinate)
            return
        }

        let avgSpeedMph     = averageMovingSpeedMph()
        let maxSpeedMph     = maxObservedSpeedMps * 2.23694
        let possibleTransit = maxSpeedMph > 95 && !isInsideVerifiedVehicle

        Task {
            let startAddress = await GeocodeCache.shared.address(for: startLoc)
            let endAddress   = await GeocodeCache.shared.address(for: endLocation)
            await MainActor.run {
                self.commitTrip(start: startLoc, end: endLocation,
                                startAddress: startAddress, endAddress: endAddress,
                                distanceMiles: distanceMiles,
                                avgSpeedMph: avgSpeedMph, maxSpeedMph: maxSpeedMph,
                                breadcrumbs: finalBreadcrumbs, needsReview: possibleTransit)
            }
        }
    }

    private func averageMovingSpeedMph() -> Double {
        let moving = speedSamples.filter { $0 > TripTrackerConfig.minimumMovingSpeedMS }
        guard !moving.isEmpty else { return 0 }
        return (moving.reduce(0, +) / Double(moving.count)) * 2.23694
    }

    private func commitTrip(start: CLLocation, end: CLLocation,
                             startAddress: String, endAddress: String,
                             distanceMiles: Double, avgSpeedMph: Double,
                             maxSpeedMph: Double,
                             breadcrumbs finalBreadcrumbs: [TripBreadcrumb],
                             needsReview: Bool) {
        let roundedMiles = (distanceMiles * 10).rounded() / 10
        let record = inProgressRecord ?? TripMemoryRecord(
            startDate: tripStartDate ?? start.timestamp, endDate: Date())
        record.endDate               = Date()
        record.startLatitude         = start.coordinate.latitude
        record.startLongitude        = start.coordinate.longitude
        record.endLatitude           = end.coordinate.latitude
        record.endLongitude          = end.coordinate.longitude
        record.startAddress          = startAddress
        record.endAddress            = endAddress
        record.totalDistanceMiles    = roundedMiles
        record.maxSpeedMph           = maxSpeedMph
        record.averageMovingSpeedMph = avgSpeedMph
        record.taxDeductionValueUSD  = roundedMiles * rate.ratePerMile
        record.breadcrumbs           = finalBreadcrumbs
        record.waypoints             = waypoints
        record.isInProgress          = false
        record.needsReview           = needsReview
        record.vehicleName           = connectedAudioDeviceName
        record.currencyCode          = rate.currencyCode
        record.updatedAt             = Date()

        // ── Persist to CoreData ──
        CoreDataManager.shared.saveTripRecord(record)

        lastCompletedTrip        = record
        lastFinalizedTrip        = record
        lastFinalizedEndLocation = end
        scheduleTripCompletedNotification(for: record)
        resetTripScopedState()
        rearmStationaryGeofence(at: end.coordinate)
        transition(to: .dormant)
        endBackgroundTask()
    }

    private func discardAndReset(rearmAt coordinate: CLLocationCoordinate2D?) {
        resetTripScopedState()
        if let c = coordinate { rearmStationaryGeofence(at: c) }
        else                  { locationManager.stopUpdatingLocation() }
        transition(to: .dormant)
        endBackgroundTask()
    }

    private func resetTripScopedState() {
        breadcrumbs.removeAll()
        waypoints.removeAll()
        accumulatedMeters    = 0
        speedSamples.removeAll()
        maxObservedSpeedMps  = 0
        lastValidLocation    = nil
        tripStartLocation    = nil
        tripStartDate        = nil
        idleBufferStartDate  = nil
        idleBufferAnchorLocation = nil
        idleBufferWorkItem?.cancel()
        idleBufferWorkItem   = nil
        inProgressRecord     = nil
        liveDistanceMiles    = 0
        liveDeductionUSD     = 0
        liveDurationSeconds  = 0
        currentSpeedMph      = 0
        lastPersistedAt      = .distantPast
        kalmanFilter.reset()
        // FIX 5: Clear the on-disk snapshot — the trip has been committed or
        // discarded so we must not resurrect it on the next cold-start.
        UserDefaults.standard.removeObject(forKey: TripTrackerService.snapshotDefaultsKey)
    }

    // MARK: - Crash-safe Snapshot (FIX 4 + FIX 5)

    /// UserDefaults key for the lightweight in-progress trip snapshot.
    /// Written on every persist tick; cleared when the trip is committed or discarded.
    private static let snapshotDefaultsKey = "com.mileagetax.inProgressSnapshot"

    private func persistInProgressSnapshot() {
        lastPersistedAt  = Date()
        let currentMiles = accumulatedMeters * 0.000621371

        if let record = inProgressRecord {
            record.endLatitude          = lastValidLocation?.coordinate.latitude  ?? record.endLatitude
            record.endLongitude         = lastValidLocation?.coordinate.longitude ?? record.endLongitude
            record.totalDistanceMiles   = currentMiles
            record.taxDeductionValueUSD = currentMiles * rate.ratePerMile
            record.breadcrumbs          = breadcrumbs
            record.waypoints            = waypoints
            record.updatedAt            = Date()
        } else {
            let r = TripMemoryRecord(startDate: tripStartDate ?? Date(), endDate: Date())
            r.startLatitude         = tripStartLocation?.coordinate.latitude  ?? 0
            r.startLongitude        = tripStartLocation?.coordinate.longitude ?? 0
            r.endLatitude           = lastValidLocation?.coordinate.latitude  ?? 0
            r.endLongitude          = lastValidLocation?.coordinate.longitude ?? 0
            r.startAddress          = "Resolving..."
            r.endAddress            = "In progress"
            r.totalDistanceMiles    = currentMiles
            r.maxSpeedMph           = maxObservedSpeedMps * 2.23694
            r.averageMovingSpeedMph = averageMovingSpeedMph()
            r.taxDeductionValueUSD  = currentMiles * rate.ratePerMile
            r.breadcrumbs           = breadcrumbs
            r.waypoints             = waypoints
            r.isInProgress          = true
            r.currencyCode          = rate.currencyCode
            inProgressRecord        = r
        }

        // FIX 5: Write a lightweight JSON snapshot to UserDefaults so that
        // resumeAnyInterruptedTripIfNeeded() can reconstruct inProgressRecord
        // after a cold-start (iOS killed + silently relaunched via .location).
        if let record = inProgressRecord {
            let snapshot = TripSnapshotData(
                startDate:          record.startDate,
                updatedAt:          record.updatedAt,
                startLatitude:      record.startLatitude,
                startLongitude:     record.startLongitude,
                endLatitude:        record.endLatitude,
                endLongitude:       record.endLongitude,
                totalDistanceMiles: record.totalDistanceMiles,
                maxSpeedMph:        record.maxSpeedMph,
                taxDeductionValueUSD: record.taxDeductionValueUSD,
                breadcrumbs:        record.breadcrumbs,
                waypoints:          record.waypoints,
                currencyCode:       record.currencyCode
            )
            if let data = try? JSONEncoder().encode(snapshot) {
                UserDefaults.standard.set(data, forKey: TripTrackerService.snapshotDefaultsKey)
            }
        }

        // ── Persist snapshot to CoreData ──
        if let snap = inProgressRecord { CoreDataManager.shared.saveTripRecord(snap) }
    }

    // MARK: - Background Task

    private func beginBackgroundTask() {
        guard backgroundTaskID == .invalid else { return }
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(
            withName: "TripFinalize") { [weak self] in self?.endBackgroundTask() }
    }

    private func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }

    // MARK: - Heartbeat (BGAppRefreshTask)

    private func scheduleNextHeartbeat() {
        let req = BGAppRefreshTaskRequest(identifier: Self.heartbeatTaskIdentifier)
        req.earliestBeginDate = Date(timeIntervalSinceNow: TripTrackerConfig.heartbeatIntervalSeconds)
        try? BGTaskScheduler.shared.submit(req)
    }

    private func handleHeartbeat(task: BGAppRefreshTask) {
        scheduleNextHeartbeat()
        // FIX 7: BGAppRefreshTask does NOT create a UIBackgroundTaskIdentifier.
        // The old handler called self?.endBackgroundTask() which targets the
        // UIBackgroundTaskIdentifier used by TripFinalize — potentially killing
        // an in-flight geocode/save before it completed.
        // Correct fix: signal the BGAppRefreshTask itself as failed.
        task.expirationHandler = { task.setTaskCompleted(success: false) }
        verifyMonitoringIntegrity()
        task.setTaskCompleted(success: true)
    }

    private func verifyMonitoringIntegrity() {
        if state == .dormant {
            let hasRegion = locationManager.monitoredRegions.contains {
                $0.identifier == Self.stationaryRegionId
            }
            if !hasRegion, let last = lastKnownAnyLocation ?? lastValidLocation {
                tripLogger.notice("Heartbeat: geofence missing — re-arming.")
                rearmStationaryGeofence(at: last.coordinate)
            }
        }
        if motionCoprocessorAvailable,
           let lastTime = lastMotionActivity?.startDate,
           Date().timeIntervalSince(lastTime) > TripTrackerConfig.motionStalenessThresholdSeconds {
            tripLogger.notice("Heartbeat: CoreMotion stale — restarting.")
            motionActivityManager.stopActivityUpdates()
            startMonitoringMotionActivity()
        }
        if state == .idleBuffer, let start = idleBufferStartDate,
           Date().timeIntervalSince(start) >
               TripTrackerConfig.idleBufferMaxExtensionSeconds + TripTrackerConfig.heartbeatIntervalSeconds {
            tripLogger.notice("Heartbeat: idleBuffer exceeded hard cap — forcing finalise.")
            evaluateIdleBufferMotionSignal(forceFinalize: true)
        }
    }

    // MARK: - Notifications

    private func registerNotificationCategories() {
        let biz = UNNotificationAction(identifier: "CLASSIFY_BUSINESS", title: "Business", options: [])
        let per = UNNotificationAction(identifier: "CLASSIFY_PERSONAL", title: "Personal", options: [])
        let cat = UNNotificationCategory(
            identifier: "TRIP_COMPLETED", actions: [biz, per],
            intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([cat])
    }

    private func scheduleTripCompletedNotification(for trip: TripMemoryRecord) {
        let content             = UNMutableNotificationContent()
        content.title           = "Drive Ended"
        content.body            = String(format: "%.1f miles ($%.2f deduction). Swipe to classify.",
                                         trip.totalDistanceMiles, trip.taxDeductionValueUSD)
        content.sound           = .default
        content.categoryIdentifier = "TRIP_COMPLETED"
        content.userInfo        = ["tripId": trip.id.uuidString]
        content.interruptionLevel = .timeSensitive
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: trip.id.uuidString, content: content, trigger: nil))
    }
}

// MARK: - CLLocationManagerDelegate

extension TripTrackerService: CLLocationManagerDelegate {

    // FIX 3: MainActor.assumeIsolated runs synchronously inside the OS callback
    // window. The old Task { @MainActor in } could be suspended before starting.

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        let ordered = locations.sorted { $0.timestamp < $1.timestamp }
        MainActor.assumeIsolated {
            for loc in ordered { self.ingest(location: loc) }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated { self.evaluateAuthorizationStatus() }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager, didExitRegion region: CLRegion
    ) {
        guard region.identifier == TripTrackerService.stationaryRegionId else { return }
        MainActor.assumeIsolated {
            guard self.state == .dormant else { return }
            self.beginMotionVerification(trigger: .geofenceExit)
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager, didVisit visit: CLVisit
    ) {
        MainActor.assumeIsolated {
            guard self.state == .dormant, visit.departureDate != .distantFuture else { return }
            self.beginMotionVerification(trigger: .visitDeparture)
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager, didFailWithError error: Error
    ) {
        MainActor.assumeIsolated {
            guard let clError = error as? CLError else { return }
            switch clError.code {
            case .denied:
                self.authorizationIssue = "Location access denied. Enable 'Always' in Settings."
            case .locationUnknown, .network:
                tripLogger.debug("Transient location error (\(clError.code.rawValue)) — will self-heal.")
            default:
                tripLogger.debug("CLError \(clError.code.rawValue)")
            }
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFinishDeferredUpdatesWithError error: Error?
    ) {
        // PATCH 1: restore elastic distance filter after deferred batch completes.
        MainActor.assumeIsolated {
            let speedMps = self.lastValidLocation?.speed ?? 0
            if speedMps > 0 {
                self.locationManager.distanceFilter = self.elasticDistanceFilter(forSpeedMps: speedMps)
            }
        }
        if let e = error {
            tripLogger.debug("Deferred updates error: \(e.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension TripTrackerService: UNUserNotificationCenterDelegate {

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let tripIdString = response.notification.request.content.userInfo["tripId"] as? String
        Task { @MainActor in
            defer { completionHandler() }
            guard let s = tripIdString, let tid = UUID(uuidString: s) else { return }
            switch response.actionIdentifier {
            case "CLASSIFY_BUSINESS": self.classify(tripId: tid, as: .business)
            case "CLASSIFY_PERSONAL": self.classify(tripId: tid, as: .personal)
            default: break
            }
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension TripTrackerService: CBCentralManagerDelegate {
    nonisolated public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // Reserved: future BLE beacon / OBD-II dongle pairing for 100% vehicle identity.
    }
}
