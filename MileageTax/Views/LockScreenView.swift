//
//  LockScreenView.swift
//  MileageTax
//

import SwiftUI

struct LockScreenView: View {
    @ObservedObject var authManager = BiometricAuthManager.shared
    
    var body: some View {
        ZStack {
            Color(hex: "#06090E").ignoresSafeArea()
            
            // Radial Glow
            RadialGradient(
                colors: [Color(hex: "#00E5FF").opacity(0.15), Color.clear],
                center: .top,
                startRadius: 10,
                endRadius: 400
            ).ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Lock Icon
                ZStack {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color(hex: "#00E5FF").opacity(0.6), Color(hex: "#00FF88").opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
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
                
                Button {
                    authManager.authenticate()
                } label: {
                    HStack {
                        Image(systemName: "lock.open.fill")
                        Text("Unlock Vault")
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(hex: "#061A13"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#00FF88"), Color(hex: "#00E5FF")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color(hex: "#00FF88").opacity(0.3), radius: 10, y: 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            // Auto trigger on load
            authManager.authenticate()
        }
    }
}
