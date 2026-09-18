//
//  BiometricAuthManager.swift
//  MileageTax
//

import Foundation
import LocalAuthentication
internal import Combine
import SwiftUI

@MainActor
final class BiometricAuthManager: ObservableObject {
    static let shared = BiometricAuthManager()
    
    @Published var isUnlocked: Bool = true
    
    private init() {}
    
    func authenticate() {
        let context = LAContext()
        var error: NSError?
        
        // Check if biometrics are available
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Unlock MileageTax to view your business ledger."
            
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                Task { @MainActor in
                    if success {
                        self.isUnlocked = true
                    } else {
                        // If it fails, they can tap to try again
                        self.isUnlocked = false
                    }
                }
            }
        } else {
            // Fallback to passcode if biometrics are not enrolled or unavailable
            if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
                let reason = "Unlock MileageTax with your device passcode."
                context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                    Task { @MainActor in
                        self.isUnlocked = success
                    }
                }
            } else {
                // Device has no security at all, just unlock
                self.isUnlocked = true
            }
        }
    }
    
    func lock() {
        isUnlocked = false
    }
}
