//
//  OnBoardingScreenView.swift
//  MileageTax — 5-slide onboarding (concept board 1, screens 3–7), all vector art.
//

import SwiftUI

struct OnBoardingScreenView: View {
    @AppStorage(AppStorageKeys.hasSeenOnboarding) private var hasSeenOnboarding = false
    @State private var page = 0
    private let count = 5

    var body: some View {
        ZStack(alignment: .bottom) {
            DS.bg.ignoresSafeArea()

            TabView(selection: $page) {
                everyMile.tag(0)
                gpsPrecise.tag(1)
                detectsDrive.tag(2)
                neverLose.tag(3)
                dataNeverLeaves.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            HStack {
                Button("Skip") { finish() }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                    .opacity(page == count - 1 ? 0 : 1)
                    .disabled(page == count - 1)
                Spacer()
                DSPageDots(count: count, index: page)
                Spacer()
                DSNextCircleButton {
                    if page == count - 1 { finish() } else { withAnimation(.spring(response: 0.45)) { page += 1 } }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .preferredColorScheme(.dark)
    }

    private func finish() { withAnimation { hasSeenOnboarding = true } }

    // MARK: - Slide scaffold

    private func slide<Art: View>(_ index: Int, first: String, second: String, subtitle: String, accent: Color = DS.cyan,
                                  @ViewBuilder background: () -> some View, @ViewBuilder art: () -> Art) -> some View {
        let active = page == index
        return ZStack {
            background()
                .scaleEffect(active ? 1 : 1.12)
                .animation(.easeOut(duration: 1.2), value: active)
                .ignoresSafeArea()
            VStack(spacing: 12) {
                TwoToneTitle(first: first, second: second, accent: accent, size: 32)
                    .reveal(active, delay: 0.05)
                Text(subtitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.7), radius: 6)
                    .padding(.horizontal, 28)
                    .reveal(active, delay: 0.15)
                art()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .reveal(active, delay: 0.28, distance: 40)
                Spacer().frame(height: 70)
            }
            .padding(.top, 24)
        }
    }

    // MARK: - Slides

    private var everyMile: some View {
        slide(0, first: "EVERY MILE", second: "MEANS MONEY",
              subtitle: "Automatically track your drives and turn them into real tax deductions.") {
            ScenicBackdrop(style: .alpineDawn, horizon: 0.52, seed: 3, photo: "scene_onboard_mile")
        } art: {
            VStack {
                Spacer()
                if UIImage(named: "scene_onboard_mile") == nil {
                Image(systemName: "car.rear.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color(hex: "#1B2630"))
                    .overlay(alignment: .bottom) {
                        HStack(spacing: 22) {
                            Capsule().fill(Color.red).frame(width: 9, height: 3)
                            Capsule().fill(Color.red).frame(width: 9, height: 3)
                        }
                        .shadow(color: .red, radius: 6)
                        .offset(y: -12)
                    }
                    .shadow(color: DS.cyan.opacity(0.4), radius: 12)
                    .offset(x: 30)
                }
                Spacer().frame(height: 60)
            }
        }
    }

    private var gpsPrecise: some View {
        slide(1, first: "GPS", second: "SO PRECISE",
              subtitle: "We detect and classify your drives with industry-leading accuracy.", accent: DS.green) {
            ZStack {
                MapRouteArt(seed: 21, photo: "scene_onboard_gps")
                LinearGradient(colors: [DS.bg.opacity(0.9), .clear, .clear, DS.bg.opacity(0.9)], startPoint: .top, endPoint: .bottom)
            }
        } art: {
            HStack {
                Spacer()
                VStack(alignment: .leading, spacing: 10) {
                    chip("briefcase.fill", "Work", "12.4 mi")
                    chip("person.2.fill", "Client Visit", "8.1 mi")
                    chip("dollarsign.circle.fill", "Business", "24.7 mi")
                }
                .padding(.trailing, 20)
            }
        }
    }

    private func chip(_ icon: String, _ title: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 14)).foregroundStyle(DS.cyan).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                Text(value).font(.system(size: 11)).foregroundStyle(DS.text2)
            }
        }
        .frame(width: 120, alignment: .leading)
        .dsGlass(radius: 12, padding: 10)
    }

    private var detectsDrive: some View {
        slide(2, first: "DETECTS", second: "YOUR DRIVE",
              subtitle: "Automatically knows when you're driving — no manual start required.") {
            ScenicBackdrop(style: .cityNight, horizon: 0.5, seed: 5, photo: "scene_onboard_detect")
        } art: {
            VStack(spacing: 0) {
                Spacer()
                if UIImage(named: "scene_onboard_detect") == nil {
                    ZStack(alignment: .bottom) {
                        SignalArcsArt(size: 260)
                        Image(systemName: "car.rear.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(Color(hex: "#151E28"))
                            .shadow(color: DS.cyan.opacity(0.5), radius: 14)
                            .offset(y: 20)
                    }
                }
                Spacer()
                HStack {
                    DSFeatureIcon(icon: "car.fill", label: "Auto Detects", highlighted: true)
                    DSFeatureIcon(icon: "sparkles", label: "AI Classifies")
                    DSFeatureIcon(icon: "bolt.fill", label: "Tracks Securely")
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private var neverLose: some View {
        slide(3, first: "NEVER LOSE", second: "A DEDUCTION",
              subtitle: "Every eligible mile is captured and ready for tax time.") {
            ScenicBackdrop(style: .mountainLake, horizon: 0.45, seed: 9, photo: "scene_onboard_deduction")
        } art: {
            VStack(spacing: 22) {
                Spacer()
                GlowShieldArt(size: 110)
                VStack(spacing: 10) {
                    DSCheckRow(text: "Drives recorded")
                    DSCheckRow(text: "Business miles tracked")
                    DSCheckRow(text: "IRS-ready reports")
                    DSCheckRow(text: "Peace of mind")
                }
                .dsGlass(radius: 16, padding: 16)
                .padding(.horizontal, 40)
                Spacer()
            }
        }
    }

    private var dataNeverLeaves: some View {
        slide(4, first: "YOUR DATA", second: "NEVER LEAVES",
              subtitle: "All your drive data is stored securely on your iPhone. Only you have access.") {
            ZStack {
                ScenicScreenBackground(image: "scene_lock")
                RadialGradient(colors: [DS.cyan.opacity(0.16), .clear], center: .center, startRadius: 0, endRadius: 320)
            }
        } art: {
            VStack(spacing: 0) {
                Spacer()
                PhoneVaultArt(size: 220)
                Spacer()
                HStack {
                    DSFeatureIcon(icon: "iphone", label: "On-Device\nStorage")
                    DSFeatureIcon(icon: "icloud.slash", label: "No Cloud\nUploads")
                    DSFeatureIcon(icon: "lock.shield", label: "You Control\nYour Data")
                }
                .padding(.horizontal, 24)
            }
        }
    }
}

private extension View {
    /// Fades and lifts content in when its page becomes active; staggered by `delay`.
    func reveal(_ active: Bool, delay: Double, distance: CGFloat = 24) -> some View {
        self.opacity(active ? 1 : 0)
            .offset(y: active ? 0 : distance)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(active ? delay : 0), value: active)
    }
}
