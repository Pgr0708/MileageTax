//
//  SharedHeaderBar.swift
//  MileageTax — Centralized Top Header Bar
//  One source of truth for app icon, brand name, notification bell, and profile avatar.
//

import SwiftUI

struct SharedHeaderBar: View {
    @Binding var showNotificationSheet: Bool
    @Binding var showProfile: Bool
    var pendingCount: Int

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Left: App Icon + Brand Name
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(hex: "#0C141E"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color(hex: "#00E5FF").opacity(0.6), Color(hex: "#00FF88").opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.2
                                )
                        )
                        .frame(width: 44, height: 44)
                        .shadow(color: Color(hex: "#00E5FF").opacity(0.25), radius: 8, x: 0, y: 3)

                    Image(systemName: "m.circle.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#00E5FF"), Color(hex: "#00FF88")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        (Text("Mileage")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        + Text("Tax")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "#00FF88")))

                        Text("PRO")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(Color(hex: "#00E5FF"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#00E5FF").opacity(0.12))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().strokeBorder(Color(hex: "#00E5FF").opacity(0.4), lineWidth: 1)
                            )
                    }

                    Text("TRACK  /  LOG  /  SAVE")
                        .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                        .tracking(1.8)
                }
            }

            Spacer()

            // Right: Notification Bell + Profile Avatar
            HStack(spacing: 10) {
                Button {
                    showNotificationSheet = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Circle()
                            .fill(Color(hex: "#0E1622").opacity(0.85))
                            .frame(width: 42, height: 42)
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))

                        Image(systemName: "bell")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(width: 42, height: 42)

                        if pendingCount > 0 {
                            Circle()
                                .fill(Color(hex: "#00FF88"))
                                .frame(width: 8, height: 8)
                                .overlay(Circle().stroke(Color(hex: "#0C141E"), lineWidth: 1.5))
                                .shadow(color: Color(hex: "#00FF88"), radius: 4)
                                .offset(x: -4, y: 4)
                        }
                    }
                }

                Button {
                    showProfile = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#0E1622").opacity(0.85))
                            .frame(width: 42, height: 42)
                            .overlay(Circle().strokeBorder(Color(hex: "#00E5FF").opacity(0.35), lineWidth: 1))

                        Image(systemName: "person.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "#00E5FF"), Color(hex: "#00FF88")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Circle()
                            .fill(Color(hex: "#00FF88"))
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(Color(hex: "#0C141E"), lineWidth: 1.5))
                            .shadow(color: Color(hex: "#00FF88"), radius: 3)
                            .offset(x: 12, y: 12)
                    }
                }
            }
        }
        .padding(.top, 2)
        .padding(.bottom, 4)
    }
}
