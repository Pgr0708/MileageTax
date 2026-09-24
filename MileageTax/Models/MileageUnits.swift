//
//  MileageUnits.swift
//  MileageTax — distance/speed/rate formatting (Single Source of Truth)
//
//  Canonical storage is ALWAYS miles and a per-mile rate. These helpers
//  convert for display when the user selects kilometres, so switching the
//  unit never corrupts stored deductions.
//

import Foundation

enum MileageUnits {

    static let kmPerMile = 1.609344
    static let milesPerKm = 1.0 / kmPerMile

    static var currentUnit: String {
        UserDefaults.standard.string(forKey: AppStorageKeys.distanceUnit) ?? MileageTaxDefaults.defaultDistanceUnit
    }

    static var currencySymbol: String {
        UserDefaults.standard.string(forKey: AppStorageKeys.currencySymbol) ?? MileageTaxDefaults.defaultCurrencySymbol
    }

    /// Best-effort ISO 4217 code for the selected symbol (used for per-trip
    /// currency metadata and exports).
    static var currencyCode: String {
        switch currencySymbol {
        case "£": return "GBP"
        case "€": return "EUR"
        case "₹": return "INR"
        case "¥": return "JPY"
        case "CA$": return "CAD"
        case "A$": return "AUD"
        case "NZ$": return "NZD"
        case "S$": return "SGD"
        case "CHF": return "CHF"
        case "R": return "ZAR"
        case "R$": return "BRL"
        case "AED": return "AED"
        case "₩": return "KRW"
        case "MX$": return "MXN"
        case "kr": return "SEK"
        default: return "USD"
        }
    }

    static var isKilometers: Bool {
        currentUnit == "km"
    }

    // MARK: - Distance

    /// Converted distance value for display (miles → km when needed).
    static func distanceValue(_ miles: Double) -> Double {
        isKilometers ? miles * kmPerMile : miles
    }

    /// "12.8 mi" or "20.6 km"
    static func distance(_ miles: Double, decimals: Int = 1) -> String {
        String(format: "%.\(decimals)f %@", distanceValue(miles), unitLabel)
    }

    /// Short unit label: "mi" or "km".
    static var unitLabel: String {
        isKilometers ? "km" : "mi"
    }

    /// Long unit label: "MILES" or "KILOMETRES".
    static var unitLabelLong: String {
        isKilometers ? "KILOMETRES" : "MILES"
    }

    // MARK: - Speed

    static func speedValue(_ mph: Double) -> Double {
        isKilometers ? mph * kmPerMile : mph
    }

    /// "22.6 mph" or "36.4 km/h"
    static func speed(_ mph: Double, decimals: Int = 1) -> String {
        String(format: "%.\(decimals)f %@", speedValue(mph), speedUnitLabel.lowercased())
    }

    static var speedUnitLabel: String {
        isKilometers ? "KM/H" : "MPH"
    }

    // MARK: - Rate

    /// Rate per displayed unit. Stored rate is per-mile; when displaying km,
    /// the per-km rate is ratePerMile / kmPerMile.
    static func ratePerDisplayUnit(_ ratePerMile: Double) -> Double {
        isKilometers ? ratePerMile / kmPerMile : ratePerMile
    }

    static func rate(_ ratePerMile: Double, decimals: Int = 3) -> String {
        String(format: "%.\(decimals)f", ratePerDisplayUnit(ratePerMile))
    }

    /// Converts a country preset rate (expressed in its native unit) into the
    /// canonical per-mile rate used for storage and deduction math.
    static func perMileRate(from nativeRate: Double, nativeUnit: String) -> Double {
        nativeUnit == "km" ? nativeRate * kmPerMile : nativeRate
    }
}
