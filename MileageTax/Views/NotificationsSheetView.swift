// NotificationsSheetView.swift — MileageTax
// Glassmorphic notification panel — shows REAL pending trip count or empty state.

import SwiftUI

struct NotificationsSheetView: View {
    @Environment(\.dismiss) private var dismiss

    /// Real pending trip count passed from RadarView
    let pendingCount: Int

    var body: some View {
        ZStack {
            Color(hex: "#06090E").ignoresSafeArea()
            RadialGradient(
                colors: [Color(hex: "#00E5FF").opacity(0.10), Color.clear],
                center: .topLeading, startRadius: 0, endRadius: 340
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Sleek drag handle
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 36, height: 4)
                    .padding(.top, 10)
                    .padding(.bottom, 12)

                // Compact Header Row
                HStack(alignment: .center) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#00E5FF").opacity(0.12))
                                .frame(width: 32, height: 32)
                            Image(systemName: "bell.badge.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color(hex: "#00E5FF"))
                        }

                        Text("Notifications")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        if pendingCount > 0 {
                            Text("\(pendingCount) NEW")
                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                .foregroundStyle(Color(hex: "#00FF88"))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color(hex: "#00FF88").opacity(0.12))
                                .clipShape(Capsule())
                                .overlay(Capsule().strokeBorder(Color(hex: "#00FF88").opacity(0.35), lineWidth: 1))
                        }
                    }

                    Spacer()

                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                // Content
                if pendingCount > 0 {
                    // Real pending trips notification
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            notificationRow(
                                icon: "doc.text.fill",
                                iconColor: Color(hex: "#00FF88"),
                                title: "\(pendingCount) Drive\(pendingCount == 1 ? "" : "s") Pending Review",
                                subtitle: "Tap to classify and unlock your unclaimed tax write-offs.",
                                time: "Now",
                                isNew: true
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 40)
                    }
                } else {
                    // Empty state
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 42, weight: .light))
                            .foregroundStyle(.white.opacity(0.2))

                        Text("All Clear")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))

                        Text("No new notifications.\nAll your drives are classified.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.3))
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func notificationRow(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        time: String,
        isNew: Bool
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(iconColor.opacity(0.25), lineWidth: 1)
                    )
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(2)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                if isNew {
                    Circle()
                        .fill(Color(hex: "#00FF88"))
                        .frame(width: 7, height: 7)
                        .shadow(color: Color(hex: "#00FF88"), radius: 4)
                }
                Text(time)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .padding(14)
        .background(Color(hex: "#0A1018").opacity(isNew ? 0.95 : 0.75))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    isNew ? Color(hex: "#00FF88").opacity(0.22) : Color.white.opacity(0.06),
                    lineWidth: 1
                )
        )
    }
}
