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

    private let defaultsKey = "MT_GeofenceZones_v1"

    private override init() {
        super.init()
        loadZones()
    }

    // MARK: - Public Actions

    func addZone(title: String, perimeterMeters: Double, tag: String, tagColorHex: String = "#00FF88", icon: String = "mappin.circle.fill", isPersonal: Bool = false) {
        let newZone = GeofenceZone(
            title: title,
            perimeterMeters: perimeterMeters,
            tag: tag,
            tagColorHex: tagColorHex,
            icon: icon,
            isPersonal: isPersonal
        )
        savedZones.append(newZone)
        persistZones()
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
            // Seed default zones matching UI Mockup
            self.savedZones = [
                GeofenceZone(
                    title: "Home (Residential)",
                    perimeterMeters: 150,
                    tag: "Auto-Origin / Personal",
                    tagColorHex: "#FF6B8B",
                    icon: "house.fill",
                    isPersonal: true
                ),
                GeofenceZone(
                    title: "Financial District HQ",
                    perimeterMeters: 200,
                    tag: "#AcmeCorp Business",
                    tagColorHex: "#00FF88",
                    icon: "building.2.fill",
                    isPersonal: false
                ),
                GeofenceZone(
                    title: "Palo Alto Tech Hub",
                    perimeterMeters: 200,
                    tag: "#Client Business",
                    tagColorHex: "#00E5FF",
                    icon: "briefcase.fill",
                    isPersonal: false
                )
            ]
            persistZones()
        }
    }

    private func persistZones() {
        if let encoded = try? JSONEncoder().encode(savedZones) {
            UserDefaults.standard.set(encoded, forKey: defaultsKey)
        }
    }
}
