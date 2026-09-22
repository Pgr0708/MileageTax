//
//  SplashScreenView.swift
//  MileageTax
//

import SwiftUI
import Lottie

extension Bundle {
    var appIcon: UIImage? {
        if let icons = infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last {
            return UIImage(named: lastIcon)
        }
        return nil
    }
}

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
                // Background
                Color(hex: "#06090E").ignoresSafeArea()
                
                Image("splash_bg")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .scaleEffect(appearAnimation ? 1.05 : 1.0) // Subtle cinematic zoom background
                
                VStack {
                    Spacer()
                    
                    // Logo & App Name
                    VStack(spacing: 20) {
                        // Safely load the AppIcon from the Bundle
                        if let icon = Bundle.main.appIcon {
                            Image(uiImage: icon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 104, height: 104)
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .shadow(color: Color(hex: "#00E5FF").opacity(0.25), radius: 20, y: 4)
                        } else {
                            // Fallback to a sleek icon if bundle lookup fails
                            Image(systemName: "car.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50, height: 50)
                                .padding(27)
                                .background(Color(hex: "#0B131D"))
                                .foregroundStyle(Color(hex: "#00E5FF"))
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .shadow(color: Color(hex: "#00E5FF").opacity(0.25), radius: 20, y: 4)
                        }
                        
                        VStack(spacing: 6) {
                            Text(AppInfo.appName)
                                .font(.system(size: 32, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .shadow(color: Color.black.opacity(0.8), radius: 4, y: 2)
                                
                            Text("100% ON-DEVICE PRIVACY")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(hex: "#00FF88"))
                                .tracking(1.5)
                                .shadow(color: Color.black.opacity(0.8), radius: 4, y: 2)
                        }
                    }
                    .opacity(appearAnimation ? 1.0 : 0.0)
                    .scaleEffect(appearAnimation ? 1.0 : 0.95)
                    
                    Spacer()
                    
                    // Loading & Version
                    VStack(spacing: 12) {
                        LottieView(animation: .named("Loading"))
                            .playing(loopMode: .loop)
                            .frame(height: 30)
                        
                        Text("Version \(AppInfo.version)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                            .shadow(color: Color.black.opacity(0.8), radius: 2, y: 1)
                    }
                    .opacity(appearAnimation ? 1.0 : 0.0)
                    .padding(.bottom, 48)
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
