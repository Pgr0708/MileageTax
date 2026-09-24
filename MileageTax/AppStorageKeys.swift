//
//  AppStorageKeys.swift
//  GoViral
//
//  Created by Minaxi on 16/08/26.
//

import Foundation

enum AppStorageKeys {
    static let isLoggedIn                  = "isLoggedIn"
    static let hasSeenOnboarding           = "hasSeenOnboarding"
    static let userName                    = "userName"
    static let profileName                 = "profileName"
    static let profileEmail                = "profileEmail"
    static let languageCode                = "languageCode"
    static let isDarkMode                  = "isDarkMode"
    
    static let hasSeenLanguage             = "hasSeenLanguage"
    static let hasSeenPaywall              = "hasSeenPaywall"

    // MARK: Notifications
    static let hasSeenNotificationPrompt   = "hasSeenNotificationPrompt"
    static let notificationsEnabled        = "notificationsEnabled"

    // MARK: Customization
    static let hasSeenCustomization        = "hasSeenCustomization"
    static let selectedAccentColor         = "selectedAccentColor"
    static let selectedTheme               = "selectedTheme"
    static let isPremium                   = "isPremium"

    // MARK: MileageTax Automations & Rules
    static let autoClassifyWorkHours       = "MT_autoClassifyWorkHours"
    static let workHoursStart              = "MT_workHoursStart"
    static let workHoursEnd                = "MT_workHoursEnd"
    static let irsRateOverride             = "MT_irsRateOverride"
    static let btGatingEnabled             = "MT_btGatingEnabled"
    static let weeklyReportEnabled         = "MT_weeklyReportEnabled"
    static let knownVehicles               = "MTKnownVehicleBluetoothNames"
    static let workDaysMask                = "MT_workDaysMask"
    static let geofenceEnabled             = "MT_geofenceEnabled"
    static let motionDetectDistanceM       = "MT_motionDetectDistanceM"   // metres
    static let motionDetectSpeedMS         = "MT_motionDetectSpeedMS"     // metres/second

    // MARK: MileageTax Global Tax & Currency
    static let currencySymbol              = "MT_currencySymbol"
    static let distanceUnit                = "MT_distanceUnit"  // "mi" or "km"
    static let countryTaxLabel             = "MT_countryTaxLabel"
}

// MARK: - MileageTax Single Source of Truth Defaults

public enum MileageTaxDefaults {
    public static let irsRatePerMile: Double      = 0.67
    public static let defaultWorkStartHour: Double = 8.0
    public static let defaultWorkEndHour: Double   = 18.0
    public static let defaultCurrencySymbol: String = "$"
    public static let defaultDistanceUnit: String   = "mi"
    public static let defaultCountryLabel: String   = "IRS Standard (USA)"
    /// Bitmask of selected work days (bit 0 = Sunday … bit 6 = Saturday).
    /// Default is Monday–Friday = 0b0111110 = 62.
    public static let defaultWorkDaysMask: Int      = 62
}


