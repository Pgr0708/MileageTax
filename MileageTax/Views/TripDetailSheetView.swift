//
//  TripDetailSheetView.swift
//  MileageTax — Phase 3: Trip Detail with Route Map (Vault History)
//

import SwiftUI
import MapKit
import CoreData

struct TripDetailSheetView: View {
    let trip: TripEntity
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppStorageKeys.currencySymbol) private var currencySymbol = "$"
    @AppStorage(AppStorageKeys.distanceUnit)   private var distanceUnit   = "mi"

    private var breadcrumbs: [TripBreadcrumb] {
        guard let data = trip.breadcrumbsData,
              let crumbs = try? JSONDecoder().decode([TripBreadcrumb].self, from: data)
        else { return [] }
        return crumbs
    }

    private var startCoord: CLLocationCoordinate2D? {
        trip.startLatitude != 0
            ? CLLocationCoordinate2D(latitude: trip.startLatitude, longitude: trip.startLongitude)
            : nil
    }

    private var endCoord: CLLocationCoordinate2D? {
        trip.endLatitude != 0
            ? CLLocationCoordinate2D(latitude: trip.endLatitude, longitude: trip.endLongitude)
            : nil
    }

    private var classificationColor: Color {
        switch trip.classification {
        case "business": return Color(hex: "#00FF88")
        case "personal": return Color(hex: "#00E5FF")
        default:         return Color.orange
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#06090E").ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {

                        // ── Route Map (top) ────────────────────────────────
                        TripRouteMapView(
                            breadcrumbs: breadcrumbs,
                            startCoord: startCoord,
                            endCoord: endCoord
                        )
                        .frame(height: UIScreen.main.bounds.height * 0.38)
                        .overlay(alignment: .bottomLeading) {
                            // Distance badge over map
                            HStack(spacing: 4) {
                                Image(systemName: "road.lanes")
                                    .font(.system(size: 11, weight: .bold))
                                Text(String(format: "%.1f %@", trip.totalDistanceMiles, distanceUnit))
                                    .font(.system(size: 13, weight: .black, design: .monospaced))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .padding(16)
                        }

                        // ── Trip Metadata Card ─────────────────────────────
                        VStack(spacing: 16) {

                            // Classification badge
                            HStack {
                                Text((trip.classification ?? "unclassified").uppercased())
                                    .font(.system(size: 11, weight: .black, design: .monospaced))
                                    .foregroundStyle(classificationColor)
                                    .padding(.horizontal, 12).padding(.vertical, 5)
                                    .background(classificationColor.opacity(0.12))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().strokeBorder(classificationColor.opacity(0.4), lineWidth: 1))
                                Spacer()
                                Text(String(format: "%@%.2f", currencySymbol, trip.taxDeductionValueUSD))
                                    .font(.system(size: 20, weight: .black, design: .monospaced))
                                    .foregroundStyle(Color(hex: "#00FF88"))
                            }

                            Divider().background(Color.white.opacity(0.08))

                            // Route info
                            VStack(spacing: 10) {
                                routeRow(icon: "smallcircle.filled.circle",
                                         color: Color(hex: "#00FF88"),
                                         label: "FROM",
                                         value: trip.startAddress ?? "Unknown")
                                routeRow(icon: "checkmark.circle.fill",
                                         color: Color(hex: "#00E5FF"),
                                         label: "TO",
                                         value: trip.endAddress ?? "Unknown")
                            }

                            Divider().background(Color.white.opacity(0.08))

                            // Stats grid
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                statCell(label: "DISTANCE",   value: String(format: "%.1f %@", trip.totalDistanceMiles, distanceUnit))
                                statCell(label: "DEDUCTION",  value: String(format: "%@%.2f", currencySymbol, trip.taxDeductionValueUSD))
                                statCell(label: "MAX SPEED",  value: String(format: "%.0f mph", trip.maxSpeedMph))
                                statCell(label: "AVG SPEED",  value: String(format: "%.0f mph", trip.averageMovingSpeedMph))
                                if let start = trip.startDate {
                                    statCell(label: "DATE",   value: start.formatted(date: .abbreviated, time: .omitted))
                                    statCell(label: "START",  value: start.formatted(date: .omitted, time: .shortened))
                                }
                                if let end = trip.endDate {
                                    statCell(label: "END",    value: end.formatted(date: .omitted, time: .shortened))
                                }
                                if let vehicle = trip.vehicleName, !vehicle.isEmpty {
                                    statCell(label: "VEHICLE", value: vehicle)
                                }
                            }

                            if let purpose = trip.businessPurpose, !purpose.isEmpty {
                                Divider().background(Color.white.opacity(0.08))
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "text.quote")
                                        .foregroundStyle(Color(hex: "#00FF88"))
                                        .font(.system(size: 13))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("BUSINESS PURPOSE")
                                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                            .foregroundStyle(.white.opacity(0.4))
                                        Text(purpose)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(.white)
                                    }
                                    Spacer()
                                }
                            }
                        }
                        .padding(20)
                        .background(Color(hex: "#0A1018").opacity(0.95))
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .padding(.horizontal, 16)
                        .padding(.top, -20) // overlap map slightly
                        .shadow(color: .black.opacity(0.3), radius: 20, y: -10)

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Trip Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color(hex: "#00FF88"))
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color(hex: "#06090E"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private func routeRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                Text(value)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }
            Spacer()
        }
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}


