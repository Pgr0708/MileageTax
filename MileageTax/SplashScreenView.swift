//
//  SplashScreenView.swift
//  MileageTax
//

import SwiftUI

struct SplashScreenView: View {
    @EnvironmentObject private var settings: SettingsManager
    @State private var isActive = false
    
    // Unified elegant animation state
    @State private var appearAnimation = false

    var body: some View {
        if isActive {
            RootView()
        } else {
            ZStack {
                ScenicBackdrop(style: .mountainLake, horizon: 0.5, photo: "scene_splash")
                    .ignoresSafeArea()
                    .scaleEffect(appearAnimation ? 1.04 : 1.0)

                VStack(spacing: 0) {
                    VStack(spacing: 10) {
                        AppLogo(size: 92)
                            .shadow(color: DS.cyan.opacity(0.45), radius: 22, y: 6)
                            .scaleEffect(appearAnimation ? 1 : 0.85)
                            .padding(.bottom, 6)
                        Wordmark(size: 42)
                            .shadow(color: .black.opacity(0.6), radius: 10, y: 3)
                        Text("DRIVE MORE BACK")
                            .font(DS.tech(12))
                            .tracking(appearAnimation ? 4 : 14)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.top, 110)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 12)

                    Spacer()

                    VStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .symbolEffect(.bounce, value: appearAnimation)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(DS.cyan)
                            .shadow(color: DS.cyan, radius: 10)
                        Text("100% ON-DEVICE PRIVACY")
                            .font(DS.display(15))
                            .foregroundStyle(.white)
                        Text("YOUR DATA STAYS ON YOUR IPHONE")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.2)
                            .foregroundStyle(.white.opacity(0.6))
                        Text("Version \(AppInfo.version)")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.35))
                            .padding(.top, 10)
                    }
                    .opacity(appearAnimation ? 1 : 0)
                    .padding(.bottom, 44)
                }
            }
            .onAppear {
                // Unified, slow, elegant cinematic fade-in
                withAnimation(.easeOut(duration: 1.8)) {
                    appearAnimation = true
                }
                
                // Transition to app
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        isActive = true
                    }
                }
            }
        }
    }
}
