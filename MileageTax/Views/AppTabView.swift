// AppTabView.swift — MileageTax
// Root 5-tab navigation shell with obsidian glass tab bar.

import SwiftUI
import CoreData

struct AppTabView: View {
    @State private var selectedTab: Int = 0
    @Environment(\.managedObjectContext) private var ctx
    @StateObject private var tracker = TripTrackerService.shared
    @StateObject private var bluetooth = BluetoothVehicleManager.shared
    @StateObject private var liveActivity = LiveActivityManager.shared

    // Deep-link support from notification
    @State private var classifyTripID: UUID? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            // ── Content ──────────────────────────────────────────────────────
            TabView(selection: $selectedTab) {
                RadarView(selectedTab: $selectedTab)
                    .tag(0)
                ClassifyView(preselectedTripID: $classifyTripID)
                    .tag(1)
                TrackView(selectedTab: $selectedTab)
                    .tag(2)
                VaultView()
                    .tag(3)
                RulesView()
                    .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // ── Custom Tab Bar ────────────────────────────────────────────────
            CustomTabBar(selected: $selectedTab, trackerState: tracker.state)
        }
        .background(Color.obsidian.ignoresSafeArea())
        .preferredColorScheme(.dark)
        // Deep-link: open Classify tab for a specific trip
        .onReceive(NotificationCenter.default.publisher(for: .openClassifyForTrip)) { notif in
            classifyTripID = notif.object as? UUID
            selectedTab = 1
        }
        // Wire Live Activity to tracker state changes
        .onReceive(tracker.$state) { state in
            handleTrackerStateChange(state)
        }
        .onReceive(tracker.$liveDistanceMiles) { miles in
            guard tracker.state == .activeTracking else { return }
            let elapsed = Int(tracker.liveDurationSeconds)
            LiveActivityManager.shared.update(
                miles:    miles,
                speed:    tracker.currentSpeedMph,
                deduction: tracker.liveDeductionUSD,
                elapsed:  elapsed,
                status:   "Active")
        }
    }

    // MARK: - Live Activity lifecycle bridge

    private func handleTrackerStateChange(_ state: TripState) {
        switch state {
        case .activeTracking:
            LiveActivityManager.shared.startActivity(
                tripID:       UUID(),
                vehicleName:  BluetoothVehicleManager.shared.connectedVehicleName ?? "Vehicle",
                startAddress: tracker.lastCompletedTrip?.startAddress ?? "Starting…")
            NotificationManager.shared.sendDriveStarted(
                address: tracker.lastCompletedTrip?.startAddress ?? "Current Location")

        case .dormant:
            LiveActivityManager.shared.stopActivity()
            if let trip = tracker.lastCompletedTrip {
                NotificationManager.shared.sendDriveFinished(
                    tripID:    trip.id,
                    miles:     trip.totalDistanceMiles,
                    deduction: trip.taxDeductionValueUSD,
                    address:   trip.endAddress)
            }
        default:
            break
        }
    }
}

// MARK: - Custom Tab Bar

private struct CustomTabBar: View {
    @Binding var selected: Int
    var trackerState: TripState

    private let items: [(icon: String, label: String)] = [
        ("chart.bar.fill", "Radar"),
        ("rectangle.stack.fill", "Classify"),
        ("location.fill", "Track"),
        ("archivebox.fill", "Vault"),
        ("brain.head.profile", "Rules"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Spacer()
                tabButton(index: index, icon: item.icon, label: item.label)
                Spacer()
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                Rectangle()
                    .fill(Color.white.opacity(0.04))
                Rectangle()
                    .fill(AppGradient.glassCard)
            }
            .overlay(
                Divider()
                    .background(Color.white.opacity(0.08)),
                alignment: .top)
        )
    }

    @ViewBuilder
    private func tabButton(index: Int, icon: String, label: String) -> some View {
        let isSelected  = selected == index
        let isTrack     = index == 2
        let isLive      = isTrack && trackerState == .activeTracking

        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selected = index
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if isLive {
                        Circle()
                            .fill(Color.crimsonPulse.opacity(0.25))
                            .frame(width: 44, height: 44)
                            .scaleEffect(isSelected ? 1.1 : 1)
                            .animation(
                                .easeInOut(duration: 1).repeatForever(autoreverses: true),
                                value: isLive)
                    }
                    Image(systemName: isLive ? "waveform.path.ecg" : icon)
                        .font(.system(size: isTrack ? 22 : 20, weight: .semibold))
                        .foregroundStyle(
                            isLive ? Color.crimsonPulse :
                            isSelected ? Color.neonEmerald :
                            Color.textSecondary)
                        .scaleEffect(isSelected ? 1.15 : 1)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                }
                .frame(width: 44, height: 34)

                Text(isLive ? "LIVE" : label)
                    .font(.micro)
                    .foregroundStyle(
                        isLive ? Color.crimsonPulse :
                        isSelected ? Color.neonEmerald :
                        Color.textTertiary)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AppTabView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
}
