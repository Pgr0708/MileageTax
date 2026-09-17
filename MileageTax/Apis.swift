//
//  Apis.swift
//  GoViral
//
//  Created by Minaxi on 16/08/26.
//

import Foundation

// MARK: - API Keys
// Add your API keys here. CLGeocoder (Apple) is used by default — no key needed.
// To switch to TomTom reverse geocoding, add your key below and update GeocodeCache in TripIntelligenceEngine.swift.

enum APIKeys {
    /// TomTom Reverse Geocoding API key (optional — leave empty to use Apple CLGeocoder for free)
    static let tomTomAPIKey: String = "" // Add your TomTom key here if needed
}
