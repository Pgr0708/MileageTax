//
//  MileageTaxEnums.swift
//  MileageTax
//
//  Centralized Enums & Models — Single Source of Truth
//

import Foundation
import SwiftUI

// MARK: - Quarter Period (Tax Schedule C)

public enum QuarterPeriod: Int, CaseIterable, Identifiable, Codable {
    case q1 = 1
    case q2 = 2
    case q3 = 3
    case q4 = 4

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .q1: return "Q1 • Jan–Mar"
        case .q2: return "Q2 • Apr–Jun"
        case .q3: return "Q3 • Jul–Sep"
        case .q4: return "Q4 • Oct–Dec"
        }
    }

    public var shortName: String {
        switch self {
        case .q1: return "Q1"
        case .q2: return "Q2"
        case .q3: return "Q3"
        case .q4: return "Q4"
        }
    }

    public var monthsRange: ClosedRange<Int> {
        switch self {
        case .q1: return 1...3
        case .q2: return 4...6
        case .q3: return 7...9
        case .q4: return 10...12
        }
    }

    public func status(for currentDate: Date = Date(), year: Int = 2026) -> QuarterStatus {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: currentDate)
        let currentMonth = calendar.component(.month, from: currentDate)

        if currentYear > year {
            return .audited
        } else if currentYear < year {
            return .upcoming
        } else {
            if monthsRange.upperBound < currentMonth {
                return .audited
            } else if monthsRange.contains(currentMonth) {
                return .active
            } else {
                return .upcoming
            }
        }
    }
}

// MARK: - Quarter Status

public enum QuarterStatus: String, CaseIterable, Codable {
    case audited = "AUDITED"
    case active = "ACTIVE"
    case upcoming = "UPCOMING"

    public var stateDescription: String {
        switch self {
        case .audited:  return "Closed & Signed"
        case .active:   return "Live Accumulator"
        case .upcoming: return "Pending"
        }
    }

    public var iconName: String {
        switch self {
        case .audited:  return "lock.fill"
        case .active:   return "clock.fill"
        case .upcoming: return "calendar"
        }
    }

    public var colorHex: String {
        switch self {
        case .audited:  return "#00FF88"
        case .active:   return "#00E5FF"
        case .upcoming: return "#8E8E93"
        }
    }
}

// MARK: - Telemetry Benchmarks & Power Metrics

public enum TelemetryBenchmark {
    public static let proDrainPerHourString: String         = "1.1%/hr"
    public static let proDrainPerDayString: String          = "1.1% / day"
    public static let proDrainRateValue: Double             = 1.1
    public static let legacyDrainPerHourString: String      = "8.5%/hr"
    public static let legacyDrainPerDayString: String       = "8.0% – 12.6% / day"
    public static let legacyDrainRateValue: Double          = 8.5
    public static let batterySavingsPercentString: String   = "-87% Battery Impact"
    public static let btBeaconLatencyMsString: String       = "14ms Ultralow Latency"
    public static let obd2StatusString: String              = "Auto-Paired"
    public static let defaultMotionSmoothScore: Double      = 99.4
    public static let defaultRtkPrecisionMeters: Double     = 1.1
}

// MARK: - Weekday (Work-Shift Schedule)

public enum Weekday: Int, CaseIterable, Identifiable, Codable, Sendable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    public var id: Int { rawValue }

    /// bit 0 = Sunday … bit 6 = Saturday (matches `Calendar.component(.weekday)`).
    public var bitValue: Int { 1 << (rawValue - 1) }

    /// Calendar's weekday component is 1 (Sunday) … 7 (Saturday).
    public init?(calendarWeekday: Int) {
        self.init(rawValue: calendarWeekday)
    }

    public var shortLabel: String {
        switch self {
        case .sunday:    return "S"
        case .monday:    return "M"
        case .tuesday:   return "T"
        case .wednesday: return "W"
        case .thursday:  return "T"
        case .friday:    return "F"
        case .saturday:  return "S"
        }
    }

    public var fullName: String {
        switch self {
        case .sunday:    return "Sunday"
        case .monday:    return "Monday"
        case .tuesday:   return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday:  return "Thursday"
        case .friday:    return "Friday"
        case .saturday:  return "Saturday"
        }
    }

    public var threeLetter: String {
        String(fullName.prefix(3))
    }

    /// Human-readable schedule label for a weekday bitmask:
    /// "Mon–Fri", "Every day", "Mon, Wed, Fri", or "No days".
    public static func scheduleLabel(forMask mask: Int) -> String {
        let days = weekdays(fromMask: mask)
        if days.isEmpty { return "No days" }
        if days.count == 7 { return "Every day" }
        if days == monToFri { return "Mon–Fri" }
        return Self.allCases.filter { days.contains($0) }.map(\.threeLetter).joined(separator: ", ")
    }

    public static func weekdays(fromMask mask: Int) -> Set<Weekday> {
        Set(Self.allCases.filter { mask & $0.bitValue != 0 })
    }

    public static func mask(from weekdays: Set<Weekday>) -> Int {
        weekdays.reduce(0) { $0 | $1.bitValue }
    }

    public static var monToFri: Set<Weekday> {
        [.monday, .tuesday, .wednesday, .thursday, .friday]
    }
}

// MARK: - Automation Rule Type

public enum AutomationRuleType: String, CaseIterable, Identifiable, Codable {
    case workHours        = "Work Hours"
    case geofenceZone     = "Geofence Zone"
    case bluetoothVehicle = "Bluetooth Vehicle"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .workHours:        return "clock.fill"
        case .geofenceZone:     return "point.3.connected.trianglepath.dotted"
        case .bluetoothVehicle: return "car.fill"
        }
    }
}

// MARK: - Automation Rule Entity (Dynamic SSOT)

public struct AutomationRule: Identifiable, Codable {
    public var id: UUID
    public var name: String
    public var type: AutomationRuleType
    public var isEnabled: Bool
    public var notes: String
    public var tag: String
    /// What happens when the rule fires.
    public var classification: TripClassification
    /// Default IRS purpose attached when classified as business (e.g. "Client Meeting").
    public var businessPurpose: String
    /// Optional schedule constraints (nil = any day/time).
    public var weekdayMask: Int?
    public var startHour: Double?
    public var endHour: Double?
    /// Geofence trigger zones.
    public var zoneIDs: [UUID]
    /// Route pairing (start place + end place).
    public var startZoneID: UUID?
    public var endZoneID: UUID?
    /// Bluetooth vehicle trigger (matched by name).
    public var vehicleName: String?
    /// Lower values evaluate first.
    public var priority: Int
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        type: AutomationRuleType,
        isEnabled: Bool = true,
        notes: String = "",
        tag: String = "#Business",
        classification: TripClassification = .business,
        businessPurpose: String = "",
        weekdayMask: Int? = nil,
        startHour: Double? = nil,
        endHour: Double? = nil,
        zoneIDs: [UUID] = [],
        startZoneID: UUID? = nil,
        endZoneID: UUID? = nil,
        vehicleName: String? = nil,
        priority: Int = 100,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.isEnabled = isEnabled
        self.notes = notes
        self.tag = tag
        self.classification = classification
        self.businessPurpose = businessPurpose
        self.weekdayMask = weekdayMask
        self.startHour = startHour
        self.endHour = endHour
        self.zoneIDs = zoneIDs
        self.startZoneID = startZoneID
        self.endZoneID = endZoneID
        self.vehicleName = vehicleName
        self.priority = priority
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, type, isEnabled, notes, tag, classification, businessPurpose
        case weekdayMask, startHour, endHour, zoneIDs, startZoneID, endZoneID
        case vehicleName, priority, createdAt
    }

    /// Lenient decoding so rules saved by earlier versions still load.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        type = try c.decodeIfPresent(AutomationRuleType.self, forKey: .type) ?? .workHours
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        tag = try c.decodeIfPresent(String.self, forKey: .tag) ?? "#Business"
        classification = try c.decodeIfPresent(TripClassification.self, forKey: .classification) ?? .business
        businessPurpose = try c.decodeIfPresent(String.self, forKey: .businessPurpose) ?? ""
        weekdayMask = try c.decodeIfPresent(Int.self, forKey: .weekdayMask)
        startHour = try c.decodeIfPresent(Double.self, forKey: .startHour)
        endHour = try c.decodeIfPresent(Double.self, forKey: .endHour)
        zoneIDs = try c.decodeIfPresent([UUID].self, forKey: .zoneIDs) ?? []
        startZoneID = try c.decodeIfPresent(UUID.self, forKey: .startZoneID)
        endZoneID = try c.decodeIfPresent(UUID.self, forKey: .endZoneID)
        vehicleName = try c.decodeIfPresent(String.self, forKey: .vehicleName)
        priority = try c.decodeIfPresent(Int.self, forKey: .priority) ?? 100
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}

// MARK: - Geofence Zone Entity (Dynamic SSOT)

public struct GeofenceZone: Identifiable, Codable {
    public let id: UUID
    public var title: String
    public var perimeterMeters: Double
    public var tag: String
    public var tagColorHex: String
    public var icon: String
    public var isPersonal: Bool
    public var latitude: Double
    public var longitude: Double

    public init(
        id: UUID = UUID(),
        title: String,
        perimeterMeters: Double,
        tag: String,
        tagColorHex: String = "#00FF88",
        icon: String = "mappin.circle.fill",
        isPersonal: Bool = false,
        latitude: Double = 37.7749,
        longitude: Double = -122.4194
    ) {
        self.id = id
        self.title = title
        self.perimeterMeters = perimeterMeters
        self.tag = tag
        self.tagColorHex = tagColorHex
        self.icon = icon
        self.isPersonal = isPersonal
        self.latitude = latitude
        self.longitude = longitude
    }
}
