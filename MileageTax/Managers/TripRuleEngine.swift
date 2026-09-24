//
//  TripRuleEngine.swift
//  MileageTax — auto-classification rule evaluation (Single Source of Truth)
//
//  Evaluated when a trip is finalized. A trip only stays `.unclassified`
//  when NO rule matches; the caller then flags it `needsReview` so it shows
//  up in the Classify deck instead of silently defaulting to personal.
//

import Foundation
import CoreLocation

@MainActor
enum TripRuleEngine {

    struct Outcome {
        let classification: TripClassification
        let tag: String?
        let ruleName: String?
    }

    /// Evaluates every enabled automation rule in priority order.
    /// Priority: Bluetooth vehicle → geofence → work-hours schedule.
    static func evaluate(
        startDate: Date,
        startCoordinate: CLLocationCoordinate2D,
        endCoordinate: CLLocationCoordinate2D,
        isInsideVerifiedVehicle: Bool,
        connectedVehicleName: String?,
        possibleTransit: Bool
    ) -> Outcome {

        // Suspicious telemetry (possible transit) must never be auto-tagged;
        // leave it unclassified so the user reviews it manually.
        if possibleTransit {
            return Outcome(classification: .unclassified, tag: nil, ruleName: nil)
        }

        // 1. Bluetooth vehicle gate — a paired/connected vehicle is a strong
        //    business signal.
        if UserDefaults.standard.bool(forKey: AppStorageKeys.btGatingEnabled),
           isInsideVerifiedVehicle,
           let name = connectedVehicleName, !name.isEmpty {
            return Outcome(classification: .business, tag: "#Business", ruleName: "Bluetooth Vehicle")
        }

        // 2. Frequent Places geofence — start OR end inside a saved zone.
        if UserDefaults.standard.bool(forKey: AppStorageKeys.geofenceEnabled) {
            let start = CLLocation(latitude: startCoordinate.latitude, longitude: startCoordinate.longitude)
            let end   = CLLocation(latitude: endCoordinate.latitude,   longitude: endCoordinate.longitude)
            for zone in GeofenceManager.shared.savedZones {
                let center = CLLocation(latitude: zone.latitude, longitude: zone.longitude)
                if start.distance(from: center) <= zone.perimeterMeters
                    || end.distance(from: center) <= zone.perimeterMeters {
                    if zone.isPersonal {
                        return Outcome(classification: .personal, tag: zone.tag, ruleName: zone.title)
                    }
                    return Outcome(classification: .business, tag: zone.tag, ruleName: zone.title)
                }
            }
        }

        // 3. Work-hours schedule (selected weekdays + time window).
        //    Defaults to ON so shift drives are auto-tagged unless the user opts out.
        let autoClassify = UserDefaults.standard.object(forKey: AppStorageKeys.autoClassifyWorkHours) as? Bool ?? true
        if autoClassify {
            let calendar = Calendar.current
            let weekdayComponent = calendar.component(.weekday, from: startDate)
            let savedMask = Int(UserDefaults.standard.integer(forKey: AppStorageKeys.workDaysMask))
            let mask = savedMask != 0 ? savedMask : MileageTaxDefaults.defaultWorkDaysMask

            if let weekday = Weekday(calendarWeekday: weekdayComponent), mask & weekday.bitValue != 0 {
                let hourOfDay = Double(calendar.component(.hour, from: startDate))
                    + Double(calendar.component(.minute, from: startDate)) / 60.0
                let startSetting = UserDefaults.standard.double(forKey: AppStorageKeys.workHoursStart)
                let endSetting   = UserDefaults.standard.double(forKey: AppStorageKeys.workHoursEnd)
                let effStart = startSetting > 0 ? startSetting : MileageTaxDefaults.defaultWorkStartHour
                let effEnd   = endSetting   > 0 ? endSetting   : MileageTaxDefaults.defaultWorkEndHour

                let inWindow: Bool
                if effStart < effEnd {
                    inWindow = hourOfDay >= effStart && hourOfDay < effEnd
                } else {
                    // Overnight shift (e.g. 20:00 → 06:00).
                    inWindow = hourOfDay >= effStart || hourOfDay < effEnd
                }
                if inWindow {
                    return Outcome(classification: .business, tag: "#Business", ruleName: "Work Hours")
                }
            }
        }

        // 4. Custom automation rules (enabled, priority-sorted).
        let custom = AutomationRuleManager.shared.customRules
            .filter { $0.isEnabled }
            .sorted { $0.priority < $1.priority }
        for rule in custom {
            if Self.matches(rule, startDate: startDate,
                            startCoordinate: startCoordinate,
                            endCoordinate: endCoordinate,
                            vehicleName: connectedVehicleName) {
                return Outcome(classification: rule.classification,
                               tag: rule.businessPurpose.isEmpty ? rule.tag : rule.businessPurpose,
                               ruleName: rule.name)
            }
        }

        return Outcome(classification: .unclassified, tag: nil, ruleName: nil)
    }

    private static func matches(_ rule: AutomationRule,
                                startDate: Date,
                                startCoordinate: CLLocationCoordinate2D,
                                endCoordinate: CLLocationCoordinate2D,
                                vehicleName: String?) -> Bool {
        // Schedule constraints (weekday + time window).
        if let mask = rule.weekdayMask {
            let calendar = Calendar.current
            if let wd = Weekday(calendarWeekday: calendar.component(.weekday, from: startDate)),
               mask & wd.bitValue == 0 { return false }
        }
        if rule.startHour != nil || rule.endHour != nil {
            let calendar = Calendar.current
            let hourOfDay = Double(calendar.component(.hour, from: startDate))
                + Double(calendar.component(.minute, from: startDate)) / 60.0
            if let s = rule.startHour, hourOfDay < s { return false }
            if let e = rule.endHour, hourOfDay >= e { return false }
        }

        // Bluetooth vehicle trigger (matched by connected audio name).
        if let required = rule.vehicleName, !required.isEmpty {
            guard let v = vehicleName?.lowercased(), v.contains(required.lowercased()) else { return false }
        }

        let zones = GeofenceManager.shared.savedZones
        func contains(_ zoneID: UUID, _ coord: CLLocationCoordinate2D) -> Bool {
            guard let zone = zones.first(where: { $0.id == zoneID }) else { return false }
            let center = CLLocation(latitude: zone.latitude, longitude: zone.longitude)
            let c = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            return c.distance(from: center) <= zone.perimeterMeters
        }

        // Any-of geofence trigger.
        if !rule.zoneIDs.isEmpty {
            let hit = rule.zoneIDs.contains { contains($0, startCoordinate) || contains($0, endCoordinate) }
            if !hit { return false }
        }

        // Route pairing (start place + end place).
        if let sid = rule.startZoneID, !contains(sid, startCoordinate) { return false }
        if let eid = rule.endZoneID, !contains(eid, endCoordinate) { return false }

        return true
    }
}
