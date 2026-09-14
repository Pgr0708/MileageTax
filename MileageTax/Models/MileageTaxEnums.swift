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
    public let id: UUID
    public var name: String
    public var type: AutomationRuleType
    public var isEnabled: Bool
    public var notes: String
    public var tag: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        type: AutomationRuleType,
        isEnabled: Bool = true,
        notes: String = "",
        tag: String = "#Business",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.isEnabled = isEnabled
        self.notes = notes
        self.tag = tag
        self.createdAt = createdAt
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
