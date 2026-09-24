//
//  GeofenceManager.swift
//  MileageTax
//
//  Single Source of Truth for Frequent Places Geofencing
//

import Foundation
import SwiftUI
import CoreLocation
internal import Combine

@MainActor
final class GeofenceManager: NSObject, ObservableObject {

    static let shared = GeofenceManager()

    @Published private(set) var savedZones: [GeofenceZone] = []

    private let defaultsKey = "MT_GeofenceZones_v4"

    private override init() {
        super.init()
        loadZones()
    }

    // MARK: - Public Actions

    func addZone(title: String, perimeterMeters: Double, tag: String,
                 tagColorHex: String = "#00FF88", icon: String = "mappin.circle.fill",
                 isPersonal: Bool = false, latitude: Double = 37.7749, longitude: Double = -122.4194) {
        let newZone = GeofenceZone(
            title: title,
            perimeterMeters: perimeterMeters,
            tag: tag,
            tagColorHex: tagColorHex,
            icon: icon,
            isPersonal: isPersonal,
            latitude: latitude,
            longitude: longitude
        )
        savedZones.append(newZone)
        persistZones()
    }

    /// Returns saved zones whose perimeter contains the given coordinate.
    func zones(containing coordinate: CLLocationCoordinate2D) -> [GeofenceZone] {
        let point = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return savedZones.filter { zone in
            let center = CLLocation(latitude: zone.latitude, longitude: zone.longitude)
            return point.distance(from: center) <= zone.perimeterMeters
        }
    }

    func removeZone(id: UUID) {
        savedZones.removeAll { $0.id == id }
        persistZones()
    }

    // MARK: - Persistence

    private func loadZones() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([GeofenceZone].self, from: data),
           !decoded.isEmpty {
            self.savedZones = decoded
        } else {
            self.savedZones = []
        }
    }

    private func persistZones() {
        if let encoded = try? JSONEncoder().encode(savedZones) {
            UserDefaults.standard.set(encoded, forKey: defaultsKey)
        }
    }
}

// MARK: - One-Shot Location Requester (for geofence center capture)

@MainActor
final class OneShotLocationRequester: NSObject, ObservableObject {
    @Published private(set) var coordinate: CLLocationCoordinate2D?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func request() {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }
}

extension OneShotLocationRequester: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coord = locations.last?.coordinate
        Task { @MainActor in self.coordinate = coord }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.coordinate = nil }
    }
}
