//
//  TripRowCard.swift
//  MileageTax
//
//  Modular Trip Row Card used across Radar, Classify, and Vault.
//

import SwiftUI

struct TripRowCard: View {
    let trip: TripEntity

    private var classColor: Color {
        switch trip.tripClassification {
        case .business:                return Color(hex: "#00FF88")
        case .personal:                return Color(hex: "#7B4FFF")
        case .unclassified, .needsReview: return Color(hex: "#FFB020")
        }
    }

    private var classIcon: String {
        switch trip.tripClassification {
        case .business:                return "briefcase.fill"
        case .personal:                return "house.fill"
        case .unclassified, .needsReview: return "questionmark.circle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Category Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(classColor.opacity(0.14))
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(classColor.opacity(0.3), lineWidth: 1)
                    )

                Image(systemName: classIcon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(classColor)
            }

            // Addresses and Date
            VStack(alignment: .leading, spacing: 3) {
                Text(trip.endAddress ?? "Trip Record")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(trip.startDate ?? Date(), style: .date)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))

                    if let startAddr = trip.startAddress, !startAddr.isEmpty {
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.3))
                        Text(startAddr)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.45))
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Mileage & Tax Deduction
            VStack(alignment: .trailing, spacing: 3) {
                Text(String(format: "+$%.2f", trip.taxDeductionValueUSD))
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(classColor)

                HStack(spacing: 3) {
                    Text(String(format: "%.1f mi", trip.totalDistanceMiles))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
        }
        .padding(12)
        .background(Color(hex: "#0A1018").opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}
