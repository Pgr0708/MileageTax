//
//  AppInfo.swift
//  MileageTax
//
//  Created by Minaxi on 16/08/26.
//

import Foundation

enum AppInfo {
    static var appName: String = "MileageTax"
    
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "com.bhavik.MileageTax"
    }

    static var supportURLString: String =   "https://sites.google.com/view/inovexa/support"
    static var termsURLString: String =     "https://sites.google.com/view/inovexa/terms-and-conditions"
    static var privacyURLString: String =   "https://sites.google.com/view/inovexa/privacy-policy"
    static var supportEmail: String =       "inovexa.contact@gmail.com"
}
