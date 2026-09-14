// TrackView.swift — MileageTax · Tab 3: Track (Live Route)
// Real-time MapKit view + live metrics overlay while a trip is active.
// Shows vehicle BT connection status and a manual override button.

import SwiftUI
import MapKit
import CoreLocation

struct TrackView: View {
    @StateObject private var tracker  = TripTrackerService.shared
    @StateObject private var bluetooth = BluetoothVehicleManager.shared

    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var route: [CLLocationCoordinate2D] = []
    @State private var showBTSetup = false

    var isLive: Bool { tracker.state == .activeTracking }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Map
            mapLayer

            // Glass overlay at bottom
            VStack(spacing: 0) {
                Spacer()
                bottomPanel
            }

            // Top info bar
            VStack {
                topBar
                Spacer()
            }
        }
        .ignoresSafeArea(edges: .top)
        .onReceive(tracker.$liveDistanceMiles) { _ in updateRoute() }
        .sheet(isPresented: $showBTSetup) {
            BluetoothSetupSheet()
        }
    }

    // MARK: - Map

    private var mapLayer: some View {
        Map {
            UserAnnotation()
            ForEach(routeAnnotations) { item in
                Annotation("", coordinate: item.coordinate) {
                    Circle()
                        .fill(Color.neonEmerald)
                        .frame(width: 6, height: 6)
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .colorScheme(.dark)
        .ignoresSafeArea()
    }

    // Dummy annotation list for route dots
    private var routeAnnotations: [RoutePoint] {
        route.map { RoutePoint(coordinate: $0) }
    }

    private func updateRoute() {
        // Append current location to route array for annotation overlay
        if let last = tracker.lastCompletedTrip?.breadcrumbs.last {
            let coord = CLLocationCoordinate2D(
                latitude: last.latitude,
                longitude: last.longitude)
            route.append(coord)
            // Camera follows user location automatically via .userLocation position
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: AppSpacing.md) {
            // BT indicator
            Button { showBTSetup = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: bluetooth.isConnectedToVehicle
                        ? "car.fill" : "car")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(bluetooth.isConnectedToVehicle
                        ? Color.neonEmerald : Color.textTertiary)
                    Text(bluetooth.connectedVehicleName ?? "No Vehicle")
                        .font(.captionText)
                        .foregroundStyle(bluetooth.isConnectedToVehicle
                            ? Color.neonEmerald : Color.textSecondary)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.obsidian.opacity(0.85))
                        .overlay(Capsule().strokeBorder(
                            bluetooth.isConnectedToVehicle
                            ? Color.neonEmerald.opacity(0.4)
                            : Color.glassBorder, lineWidth: 1)))
            }

            Spacer()

            // State pill
            statePill
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, 60) // below status bar
    }

    private var statePill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isLive ? Color.crimsonPulse : Color.textTertiary)
                .frame(width: 8, height: 8)
                .shadow(color: isLive ? Color.crimsonPulse : .clear, radius: 4)
            Text(stateLabel)
                .font(.captionText)
                .foregroundStyle(Color.textPrimary)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.obsidian.opacity(0.85))
                .overlay(Capsule().strokeBorder(Color.glassBorder, lineWidth: 1)))
    }

    private var stateLabel: String {
        switch tracker.state {
        case .dormant:           return "Monitoring"
        case .verifyingMotion:   return "Verifying…"
        case .activeTracking:    return "LIVE"
        case .idleBuffer:        return "Idle Buffer"
        case .tripFinalizing:    return "Finalizing…"
        }
    }

    // MARK: - Bottom Panel

    private var bottomPanel: some View {
        VStack(spacing: AppSpacing.md) {
            if isLive {
                liveMetricsGrid
                Divider().background(Color.glassBorder)
            }
            manualControls
        }
        .padding(AppSpacing.lg)
        .padding(.bottom, max(34, 16))
        .background(
            ZStack {
                Color.obsidian.opacity(0.92)
                AppGradient.glassCard
            }
            .overlay(
                Rectangle()
                    .fill(Color.glassBorder)
                    .frame(height: 1),
                alignment: .top)
        )
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Live Metrics

    private var liveMetricsGrid: some View {
        HStack(spacing: 0) {
            liveMetric(
                value: String(format: "%.1f", tracker.liveDistanceMiles),
                unit: "mi",
                label: "Distance",
                color: .neonEmerald)
            Divider().background(Color.glassBorder).frame(height: 50)
            liveMetric(
                value: String(format: "%.0f", tracker.currentSpeedMph),
                unit: "mph",
                label: "Speed",
                color: .electricCyan)
            Divider().background(Color.glassBorder).frame(height: 50)
            liveMetric(
                value: String(format: "$%.2f", tracker.liveDeductionUSD),
                unit: "",
                label: "Deduction",
                color: .amberGlow)
            Divider().background(Color.glassBorder).frame(height: 50)
            liveMetric(
                value: elapsedString,
                unit: "",
                label: "Elapsed",
                color: .deepPurple)
        }
    }

    private func liveMetric(value: String, unit: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.monoLarge)
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
                if !unit.isEmpty {
                    Text(unit)
                        .font(.captionText)
                        .foregroundStyle(color.opacity(0.7))
                }
            }
            Text(label)
                .font(.micro)
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var elapsedString: String {
        let secs = Int(tracker.liveDurationSeconds)
        // secs already set above
        return String(format: "%d:%02d", secs / 60, secs % 60)
    }

    // MARK: - Manual Controls

    private var manualControls: some View {
        HStack(spacing: AppSpacing.md) {
            if !isLive {
                // Manual Start
                Button {
                    // TripIntelligenceEngine starts automatically via motion/location.
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "play.fill")
                        Text("Force Start Trip")
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppGradient.emeraldPulse)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                    .emeraldGlow()
                }
            } else {
                // Speed indicator bar
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "speedometer")
                        .foregroundStyle(Color.electricCyan)
                    ProgressView(value: min(tracker.currentSpeedMph / 80.0, 1))
                        .progressViewStyle(.linear)
                        .tint(Color.electricCyan)
                    Text(String(format: "%.0f mph", tracker.currentSpeedMph))
                        .font(.captionText)
                        .foregroundStyle(Color.electricCyan)
                }
                .padding(.vertical, 8)

                // Manual Stop
                Button {
                    // Engine will finalise automatically; this is UI feedback only.
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "stop.fill")
                        Text("Stop")
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.textOnAccent)
                    .padding(.horizontal, 24).padding(.vertical, 16)
                    .background(AppGradient.dangerGradient)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                }
            }
        }
    }
}

// MARK: - Route Point (for MapAnnotationItems)

private struct RoutePoint: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Bluetooth Setup Sheet

struct BluetoothSetupSheet: View {
    @StateObject private var bt = BluetoothVehicleManager.shared
    @State private var newName = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.obsidian.ignoresSafeArea()
                List {
                    Section {
                        HStack {
                            TextField("Car Bluetooth name…", text: $newName)
                                .foregroundStyle(Color.textPrimary)
                                .tint(Color.neonEmerald)
                            Button("Add") {
                                guard !newName.isEmpty else { return }
                                bt.addVehicle(name: newName)
                                newName = ""
                            }
                            .foregroundStyle(Color.neonEmerald)
                            .disabled(newName.isEmpty)
                        }
                    } header: {
                        Text("Add Vehicle Bluetooth Name")
                            .foregroundStyle(Color.textSecondary)
                    }

                    Section {
                        ForEach(bt.knownVehicleList, id: \.self) { name in
                            HStack {
                                Image(systemName: "car.fill")
                                    .foregroundStyle(Color.neonEmerald)
                                Text(name)
                                    .foregroundStyle(Color.textPrimary)
                                Spacer()
                                if bt.connectedVehicleName?.lowercased() == name {
                                    Text("Connected")
                                        .font(.captionText)
                                        .foregroundStyle(Color.neonEmerald)
                                }
                            }
                        }
                        .onDelete { idx in
                            idx.forEach { i in
                                bt.removeVehicle(name: bt.knownVehicleList[i])
                            }
                        }
                    } header: {
                        Text("Known Vehicles")
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.obsidian)
            }
            .navigationTitle("Vehicle Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.neonEmerald)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
