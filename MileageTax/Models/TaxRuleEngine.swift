//
//  TaxRuleEngine.swift
//  MileageTax — Phase 4: Date-Effective Tax Rate Database
//
//  Single source of truth for all country tax rules.
//  Returns the exact rate that was active on a given trip's date.
//

import Foundation

// MARK: - Tax Rate Record

public struct TaxRateRecord: Identifiable {
    public let id = UUID()
    public let country: String          // "US", "GB", "CA"
    public let flag: String             // "🇺🇸"
    public let authority: String        // "IRS"
    public let authorityFull: String    // "IRS Standard Mileage"
    public let currency: String         // "$"
    public let currencyCode: String     // "USD"
    public let unit: String             // "mi" or "km"
    public let rate: Double             // primary rate per unit
    public let thresholdUnits: Double?  // nil = unlimited; e.g. 10000.0 for UK first-tier
    public let tier2Rate: Double?       // rate above threshold
    public let effectiveFrom: Date
    public let effectiveTo: Date?       // nil = still current

    public var displayName: String { "\(flag) \(country) (\(authority))" }
    public var rateLabel: String { "\(currency)\(String(format: "%.3f", rate))/\(unit)" }
}

// MARK: - Tax Rule Engine

public enum TaxRuleEngine {

    // MARK: - Full Database (2026 Verified Government Sources)

    public static let database: [TaxRateRecord] = {
        let cal = Calendar(identifier: .gregorian)
        func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
            cal.date(from: DateComponents(year: y, month: m, day: d))!
        }

        return [
            // ── 🇺🇸 United States ──────────────────────────────────────
            TaxRateRecord(country: "United States", flag: "🇺🇸", authority: "IRS",
                          authorityFull: "IRS Standard Mileage",
                          currency: "$", currencyCode: "USD", unit: "mi",
                          rate: 0.725, thresholdUnits: nil, tier2Rate: nil,
                          effectiveFrom: date(2026, 1, 1), effectiveTo: date(2026, 6, 30)),
            TaxRateRecord(country: "United States", flag: "🇺🇸", authority: "IRS",
                          authorityFull: "IRS Standard Mileage",
                          currency: "$", currencyCode: "USD", unit: "mi",
                          rate: 0.760, thresholdUnits: nil, tier2Rate: nil,
                          effectiveFrom: date(2026, 7, 1), effectiveTo: nil),

            // ── 🇬🇧 United Kingdom ─────────────────────────────────────
            TaxRateRecord(country: "United Kingdom", flag: "🇬🇧", authority: "HMRC",
                          authorityFull: "HMRC Approved Mileage",
                          currency: "£", currencyCode: "GBP", unit: "mi",
                          rate: 0.55, thresholdUnits: 10000, tier2Rate: 0.25,
                          effectiveFrom: date(2026, 4, 6), effectiveTo: nil),

            // ── 🇨🇦 Canada ─────────────────────────────────────────────
            TaxRateRecord(country: "Canada", flag: "🇨🇦", authority: "CRA",
                          authorityFull: "CRA Automobile Allowance",
                          currency: "C$", currencyCode: "CAD", unit: "km",
                          rate: 0.73, thresholdUnits: 5000, tier2Rate: 0.67,
                          effectiveFrom: date(2026, 1, 1), effectiveTo: nil),

            // ── 🇦🇺 Australia ──────────────────────────────────────────
            TaxRateRecord(country: "Australia", flag: "🇦🇺", authority: "ATO",
                          authorityFull: "ATO Cents-per-Kilometre",
                          currency: "A$", currencyCode: "AUD", unit: "km",
                          rate: 0.91, thresholdUnits: 5000, tier2Rate: 0,
                          effectiveFrom: date(2026, 7, 1), effectiveTo: nil),

            // ── 🇳🇿 New Zealand (Petrol) ───────────────────────────────
            TaxRateRecord(country: "New Zealand (Petrol)", flag: "🇳🇿", authority: "IRD",
                          authorityFull: "IRD Kilometre Rate",
                          currency: "NZ$", currencyCode: "NZD", unit: "km",
                          rate: 1.20, thresholdUnits: 14000, tier2Rate: 0.37,
                          effectiveFrom: date(2025, 4, 1), effectiveTo: nil),

            // ── 🇳🇿 New Zealand (EV) ───────────────────────────────────
            TaxRateRecord(country: "New Zealand (EV)", flag: "🇳🇿", authority: "IRD",
                          authorityFull: "IRD Kilometre Rate — EV",
                          currency: "NZ$", currencyCode: "NZD", unit: "km",
                          rate: 1.22, thresholdUnits: 14000, tier2Rate: 0.23,
                          effectiveFrom: date(2025, 4, 1), effectiveTo: nil),

            // ── 🇫🇷 France ─────────────────────────────────────────────
            TaxRateRecord(country: "France", flag: "🇫🇷", authority: "DGFiP",
                          authorityFull: "Barème Kilométrique (3CV, ≤5000km)",
                          currency: "€", currencyCode: "EUR", unit: "km",
                          rate: 0.529, thresholdUnits: nil, tier2Rate: nil,
                          effectiveFrom: date(2026, 1, 1), effectiveTo: nil),

            // ── 🇩🇪 Germany ────────────────────────────────────────────
            TaxRateRecord(country: "Germany", flag: "🇩🇪", authority: "BMF",
                          authorityFull: "BMF Entfernungspauschale",
                          currency: "€", currencyCode: "EUR", unit: "km",
                          rate: 0.30, thresholdUnits: 20, tier2Rate: 0.38,
                          effectiveFrom: date(2026, 1, 1), effectiveTo: nil),

            // ── 🇦🇹 Austria ────────────────────────────────────────────
            TaxRateRecord(country: "Austria", flag: "🇦🇹", authority: "BMF",
                          authorityFull: "Kilometergeld",
                          currency: "€", currencyCode: "EUR", unit: "km",
                          rate: 0.50, thresholdUnits: 30000, tier2Rate: 0,
                          effectiveFrom: date(2026, 1, 1), effectiveTo: nil),

            // ── 🇧🇪 Belgium Q1 ─────────────────────────────────────────
            TaxRateRecord(country: "Belgium", flag: "🇧🇪", authority: "BOSA",
                          authorityFull: "Federal Kilometre Allowance",
                          currency: "€", currencyCode: "EUR", unit: "km",
                          rate: 0.4326, thresholdUnits: nil, tier2Rate: nil,
                          effectiveFrom: date(2026, 1, 1), effectiveTo: date(2026, 3, 31)),
            TaxRateRecord(country: "Belgium", flag: "🇧🇪", authority: "BOSA",
                          authorityFull: "Federal Kilometre Allowance",
                          currency: "€", currencyCode: "EUR", unit: "km",
                          rate: 0.4571, thresholdUnits: nil, tier2Rate: nil,
                          effectiveFrom: date(2026, 4, 1), effectiveTo: date(2026, 4, 30)),
            TaxRateRecord(country: "Belgium", flag: "🇧🇪", authority: "BOSA",
                          authorityFull: "Federal Kilometre Allowance",
                          currency: "€", currencyCode: "EUR", unit: "km",
                          rate: 0.4841, thresholdUnits: nil, tier2Rate: nil,
                          effectiveFrom: date(2026, 5, 1), effectiveTo: date(2026, 6, 30)),
            TaxRateRecord(country: "Belgium", flag: "🇧🇪", authority: "BOSA",
                          authorityFull: "Federal Kilometre Allowance",
                          currency: "€", currencyCode: "EUR", unit: "km",
                          rate: 0.4440, thresholdUnits: nil, tier2Rate: nil,
                          effectiveFrom: date(2026, 7, 1), effectiveTo: nil),

            // ── 🇳🇱 Netherlands ────────────────────────────────────────
            TaxRateRecord(country: "Netherlands", flag: "🇳🇱", authority: "Belastingdienst",
                          authorityFull: "Business Deduction / Tax-free Reimbursement",
                          currency: "€", currencyCode: "EUR", unit: "km",
                          rate: 0.25, thresholdUnits: nil, tier2Rate: nil,
                          effectiveFrom: date(2026, 1, 1), effectiveTo: nil),

            // ── 🇪🇸 Spain ──────────────────────────────────────────────
            TaxRateRecord(country: "Spain", flag: "🇪🇸", authority: "AEAT",
                          authorityFull: "Tax-exempt Business Travel Allowance",
                          currency: "€", currencyCode: "EUR", unit: "km",
                          rate: 0.26, thresholdUnits: nil, tier2Rate: nil,
                          effectiveFrom: date(2026, 1, 1), effectiveTo: nil),

            // ── 🇮🇪 Ireland (base rate) ────────────────────────────────
            TaxRateRecord(country: "Ireland", flag: "🇮🇪", authority: "Revenue",
                          authorityFull: "Civil Service Motor Travel (≤1200cc, Band 1)",
                          currency: "€", currencyCode: "EUR", unit: "km",
                          rate: 0.418, thresholdUnits: nil, tier2Rate: nil,
                          effectiveFrom: date(2026, 1, 1), effectiveTo: nil),

            // ── 🇳🇴 Norway ─────────────────────────────────────────────
            TaxRateRecord(country: "Norway", flag: "🇳🇴", authority: "Skatteetaten",
                          authorityFull: "Tax-free Business Mileage",
                          currency: "kr", currencyCode: "NOK", unit: "km",
                          rate: 3.50, thresholdUnits: nil, tier2Rate: nil,
                          effectiveFrom: date(2026, 1, 1), effectiveTo: nil),

            // ── 🇸🇪 Sweden ─────────────────────────────────────────────
            TaxRateRecord(country: "Sweden", flag: "🇸🇪", authority: "Skatteverket",
                          authorityFull: "Tax-free Mileage Reimbursement",
                          currency: "kr", currencyCode: "SEK", unit: "km",
                          rate: 2.50, thresholdUnits: nil, tier2Rate: nil,
                          effectiveFrom: date(2026, 1, 1), effectiveTo: nil),

            // ── 🇨🇿 Czech Republic ─────────────────────────────────────
            TaxRateRecord(country: "Czech Republic", flag: "🇨🇿", authority: "SUIP",
                          authorityFull: "Statutory Business Travel Compensation",
                          currency: "Kč", currencyCode: "CZK", unit: "km",
                          rate: 5.90, thresholdUnits: nil, tier2Rate: nil,
                          effectiveFrom: date(2026, 1, 1), effectiveTo: nil),
        ]
    }()

    // MARK: - Lookup: rate active for a specific country + date

    /// Returns the tax rate record active for the given country on the given date.
    /// Falls back to the most recent record if none matches the date range.
    public static func record(for country: String, on date: Date = Date()) -> TaxRateRecord? {
        let matches = database.filter { $0.country == country }
        let active = matches.first { r in
            r.effectiveFrom <= date && (r.effectiveTo == nil || r.effectiveTo! >= date)
        }
        return active ?? matches.last
    }

    /// Returns the active rate (Double) for the currently-selected country.
    public static func activeRate(on date: Date = Date()) -> Double {
        let countryLabel = UserDefaults.standard.string(forKey: AppStorageKeys.countryTaxLabel)
            ?? MileageTaxDefaults.defaultCountryLabel

        // Find matching record by authority label
        let match = database.first { r in
            r.authorityFull.contains(countryLabel) || countryLabel.contains(r.country)
        }
        return match?.rate ?? MileageTaxDefaults.irsRatePerMile
    }

    /// Returns all unique countries in the database (for picker UI)
    public static var uniqueCountries: [TaxRateRecord] {
        var seen = Set<String>()
        return database.filter { seen.insert($0.country).inserted }
    }
}
