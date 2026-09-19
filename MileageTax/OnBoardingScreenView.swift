//
//  OnBoardingScreenView.swift
//  MileageTax — Cinematic 5-Slide Onboarding
//

import SwiftUI

private struct OnboardSlide: Identifiable {
    let id: Int
    let imageName: String
    let badge: String
    let badgeIcon: String
    let title: String
    let subtitle: String
    let accentHex: String
}

private let slides: [OnboardSlide] = [
    OnboardSlide(id: 0, imageName: "onboard_slide1",
                 badge: "IRS §162 COMPLIANT", badgeIcon: "checkmark.shield.fill",
                 title: "Every Mile\nMeans Money",
                 subtitle: "The IRS pays you $0.67 per business mile. Most drivers miss thousands every year. Not anymore.",
                 accentHex: "#00FF88"),
    OnboardSlide(id: 1, imageName: "onboard_slide2",
                 badge: "KALMAN FILTER GPS", badgeIcon: "location.viewfinder",
                 title: "GPS So Precise\nIt's Scary",
                 subtitle: "Military-grade Kalman filtering locks your route to ±5 meters. Every turn. Every block. Perfectly captured.",
                 accentHex: "#00E5FF"),
    OnboardSlide(id: 2, imageName: "onboard_slide3",
                 badge: "COREMOTION RADAR", badgeIcon: "antenna.radiowaves.left.and.right",
                 title: "Detects Your Drive\nAutomatically",
                 subtitle: "Our 7-layer intelligence engine knows you're driving before you even buckle up. Zero effort required.",
                 accentHex: "#00FF88"),
    OnboardSlide(id: 3, imageName: "onboard_slide4",
                 badge: "IRS AUDIT SHIELD", badgeIcon: "building.columns.fill",
                 title: "Never Lose\na Deduction Again",
                 subtitle: "Every trip is timestamped, geocoded, and IRS §274 validated. Your vault is airtight.",
                 accentHex: "#FFD700"),
    OnboardSlide(id: 4, imageName: "onboard_slide5",
                 badge: "100% ON-DEVICE", badgeIcon: "lock.shield.fill",
                 title: "Your Data\nNever Leaves",
                 subtitle: "No cloud. No servers. No tracking. Your routes, addresses, and earnings stay locked on your iPhone.",
                 accentHex: "#00E5FF")
]

struct OnBoardingScreenView: View {
    @AppStorage(AppStorageKeys.hasSeenOnboarding) private var hasSeenOnboarding = false
    @State private var currentPage = 0
    @State private var contentOpacity: Double = 0
    @State private var contentOffset: CGFloat = 40
    @State private var badgeScale: CGFloat = 0.7
    @State private var imageScale: CGFloat = 1.08
    @State private var dragOffset: CGFloat = 0

    private var slide: OnboardSlide { slides[currentPage] }
    private var accent: Color { Color(hex: slide.accentHex) }

    var body: some View {
        ZStack {
            Color(hex: "#06090E").ignoresSafeArea()
            GeometryReader { geo in
                let topSafe = max(geo.safeAreaInsets.top, 50)
                ZStack(alignment: .bottom) {
                    // Hero image with safe area headroom so logos never get cut off
                    Image(slide.imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height * 0.62)
                        .clipped()
                        .frame(maxHeight: .infinity, alignment: .top)
                        .padding(.top, topSafe + 6)
                        .animation(.easeInOut(duration: 0.4), value: currentPage)

                    // Gradient overlay fading seamlessly into background
                    VStack {
                        Spacer()
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: Color(hex: "#06090E").opacity(0.45), location: 0.3),
                                .init(color: Color(hex: "#06090E").opacity(0.92), location: 0.58),
                                .init(color: Color(hex: "#06090E"), location: 0.75)
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                        .frame(height: geo.size.height * 0.72)
                    }
                    .ignoresSafeArea()

                    // Bottom content
                    VStack(spacing: 20) {
                        // Badge pill
                        HStack(spacing: 6) {
                            Image(systemName: slide.badgeIcon)
                                .font(.system(size: 10, weight: .black))
                            Text(slide.badge)
                                .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                        }
                        .foregroundStyle(accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(accent.opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(accent.opacity(0.45), lineWidth: 1))
                        .shadow(color: accent.opacity(0.3), radius: 8)
                        .scaleEffect(badgeScale)

                        // Title
                        Text(slide.title)
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .opacity(contentOpacity)
                            .offset(y: contentOffset)

                        // Subtitle
                        Text(slide.subtitle)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 8)
                            .opacity(contentOpacity)
                            .offset(y: contentOffset)

                        // Page indicator
                        HStack(spacing: 6) {
                            ForEach(0..<slides.count, id: \.self) { i in
                                Capsule()
                                    .fill(i == currentPage ? accent : Color.white.opacity(0.2))
                                    .frame(width: i == currentPage ? 26 : 7, height: 7)
                                    .animation(.spring(response: 0.4), value: currentPage)
                            }
                        }
                        .padding(.top, 4)

                        // CTA
                        Button {
                            if currentPage == slides.count - 1 { finish() }
                            else { advance() }
                        } label: {
                            HStack(spacing: 10) {
                                Text(currentPage == slides.count - 1 ? "Let's Go" : "Continue")
                                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                                Image(systemName: currentPage == slides.count - 1 ? "arrow.up.right" : "chevron.right")
                                    .font(.system(size: 14, weight: .black))
                            }
                            .foregroundStyle(Color(hex: "#06090E"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(colors: [accent, accent.opacity(0.75)],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(Capsule())
                            .shadow(color: accent.opacity(0.55), radius: 16, y: 6)
                        }
                        .buttonStyle(.plain)

                        Spacer().frame(height: max(geo.safeAreaInsets.bottom, 20))
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 8)
                }
            }
            .ignoresSafeArea()
            .gesture(
                DragGesture()
                    .onEnded { v in
                        if v.translation.width < -60 && currentPage < slides.count - 1 { advance() }
                        else if v.translation.width > 60 && currentPage > 0 {
                            withAnimation(.spring(response: 0.4)) { currentPage -= 1 }
                            animateIn()
                        }
                    }
            )

            // Skip button
            VStack {
                HStack {
                    Spacer()
                    Button { finish() } label: {
                        Text("Skip")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(hex: "#06090E").opacity(0.65))
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
                    }
                }
                .padding(.top, max(Device.topSafeArea, 50) + 8)
                .padding(.trailing, 16)
                Spacer()
            }
        }
        .onAppear { animateIn() }
    }

    private func advance() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { currentPage += 1 }
        animateIn()
    }

    private func finish() {
        withAnimation { hasSeenOnboarding = true }
    }

    private func animateIn() {
        contentOpacity = 0; contentOffset = 32; badgeScale = 0.7; imageScale = 1.08
        withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
            contentOpacity = 1; contentOffset = 0; badgeScale = 1.0; imageScale = 1.0
        }
    }
}
