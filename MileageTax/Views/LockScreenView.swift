//
//  LockScreenView.swift
//  MileageTax
//

import SwiftUI
import LocalAuthentication

// MARK: - PIN Storage Key
private let pinStorageKey = "MT_vaultPIN"

struct LockScreenView: View {
    @ObservedObject var authManager = BiometricAuthManager.shared
    @AppStorage("MT_faceIDLockEnabled") private var faceIDLockEnabled = true

    @State private var showPINEntry = false
    @State private var enteredPIN = ""
    @State private var savedPIN: String = UserDefaults.standard.string(forKey: pinStorageKey) ?? ""
    @State private var pinError = false
    @State private var isSettingPIN = false    // true when no PIN set yet
    @State private var confirmPIN = ""
    @State private var showConfirm = false

    private var hasPINSet: Bool { !savedPIN.isEmpty }

    var body: some View {
        ZStack {
            Color(hex: "#06090E").ignoresSafeArea()
            RadialGradient(
                colors: [Color(hex: "#00E5FF").opacity(0.15), Color.clear],
                center: .top, startRadius: 10, endRadius: 400
            ).ignoresSafeArea()

            if showPINEntry {
                pinScreen
            } else {
                biometricScreen
            }
        }
        .onAppear {
            authManager.authenticate()
        }
    }

    // MARK: - Biometric Screen
    private var biometricScreen: some View {
        VStack(spacing: 32) {
            Spacer()
            ZStack {
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color(hex: "#00E5FF").opacity(0.6), Color(hex: "#00FF88").opacity(0.2)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 104, height: 104)
                Image(systemName: "faceid")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(Color(hex: "#00FF88"))
            }

            VStack(spacing: 8) {
                Text("Vault Locked")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("Authenticate to access your business ledger.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()

            VStack(spacing: 12) {
                Button { authManager.authenticate() } label: {
                    HStack {
                        Image(systemName: "lock.open.fill")
                        Text("Unlock with Face ID / Touch ID")
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(hex: "#061A13"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#00FF88"), Color(hex: "#00E5FF")],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color(hex: "#00FF88").opacity(0.3), radius: 10, y: 4)
                }

                // Fallback: use PIN
                Button {
                    isSettingPIN = !hasPINSet
                    showPINEntry = true
                    enteredPIN = ""
                    pinError = false
                } label: {
                    Text(hasPINSet ? "Use Passcode Instead" : "Set Up Passcode")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    // MARK: - PIN Screen
    private var pinScreen: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color(hex: "#00E5FF"))

            Text(isSettingPIN
                 ? (showConfirm ? "Confirm Your Passcode" : "Set New Passcode")
                 : "Enter Passcode")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            // PIN dots
            HStack(spacing: 16) {
                ForEach(0..<4) { i in
                    Circle()
                        .fill(pinDisplay.count > i ? Color(hex: "#00FF88") : Color.white.opacity(0.2))
                        .frame(width: 16, height: 16)
                }
            }

            if pinError {
                Text(isSettingPIN ? "Passcodes don't match. Try again." : "Incorrect passcode.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.red.opacity(0.8))
            }

            Spacer()

            // Numpad
            numpad

            Button("Cancel") {
                showPINEntry = false
                enteredPIN = ""
                confirmPIN = ""
                showConfirm = false
                pinError = false
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white.opacity(0.5))
            .padding(.bottom, 24)
        }
    }

    private var pinDisplay: String {
        showConfirm ? confirmPIN : enteredPIN
    }

    private var numpad: some View {
        let digits = ["1","2","3","4","5","6","7","8","9","⌫","0","✓"]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
            ForEach(digits, id: \.self) { d in
                Button {
                    handleDigit(d)
                } label: {
                    Text(d)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 72, height: 72)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 40)
    }

    private func handleDigit(_ d: String) {
        pinError = false
        if d == "⌫" {
            if showConfirm {
                if !confirmPIN.isEmpty { confirmPIN.removeLast() }
            } else {
                if !enteredPIN.isEmpty { enteredPIN.removeLast() }
            }
            return
        }
        if d == "✓" {
            submitPIN()
            return
        }
        if showConfirm {
            if confirmPIN.count < 4 { confirmPIN.append(d) }
            if confirmPIN.count == 4 { submitPIN() }
        } else {
            if enteredPIN.count < 4 { enteredPIN.append(d) }
            if enteredPIN.count == 4 { submitPIN() }
        }
    }

    private func submitPIN() {
        if isSettingPIN {
            if !showConfirm {
                // First entry — show confirm screen
                showConfirm = true
            } else {
                // Confirm entry
                if confirmPIN == enteredPIN {
                    UserDefaults.standard.set(enteredPIN, forKey: pinStorageKey)
                    savedPIN = enteredPIN
                    authManager.isUnlocked = true
                } else {
                    pinError = true
                    confirmPIN = ""
                }
            }
        } else {
            // Verify PIN
            if enteredPIN == savedPIN {
                authManager.isUnlocked = true
            } else {
                pinError = true
                enteredPIN = ""
            }
        }
    }
}
