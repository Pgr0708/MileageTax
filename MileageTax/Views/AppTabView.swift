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
            .ignoresSafeArea()

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

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TripEntity.startDate, ascending: false)],
        predicate: NSPredicate(format: "needsReview == true AND isInProgress == false"),
        animation: .default)
    private var pendingTrips: FetchedResults<TripEntity>

    private let items: [(icon: String, label: String)] = [
        ("safari", "Radar"),
        ("tag.fill", "Classify"),
        ("bolt.fill", "TRACK"),
        ("building.columns.fill", "Vault"),
        ("gearshape.fill", "Rules"),
    ]

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Spacer()
                if index == 2 {
                    // Center Elevated Neon TRACK Button
                    centerTrackButton(icon: item.icon, label: item.label)
                } else {
                    regularTabButton(index: index, icon: item.icon, label: item.label)
                }
                Spacer()
            }
        }
        .padding(.top, 8)
//        .padding(.bottom, 20)
        .background(
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                Rectangle()
                    .fill(Color(hex: "#060A10").opacity(0.72))
                
                // Subtle bottom emerald aurora glow
                RadialGradient(
                    colors: [Color(hex: "#00FF88").opacity(0.12), Color.clear],
                    center: .bottom,
                    startRadius: 0,
                    endRadius: 180
                )
            }
            .overlay(
                LinearGradient(
                    colors: [Color(hex: "#00E5FF").opacity(0.35), Color(hex: "#00FF88").opacity(0.2), Color.white.opacity(0.06)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 1),
                alignment: .top
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    // Regular Tab Button
    @ViewBuilder
    private func regularTabButton(index: Int, icon: String, label: String) -> some View {
        let isSelected = selected == index
        let pendingCount = pendingTrips.count  // real count only, no dummy fallback

        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selected = index
            }
        } label: {
            VStack(spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 19, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(
                            isSelected ? Color(hex: "#00E5FF") : Color.white.opacity(0.45)
                        )
                        .scaleEffect(isSelected ? 1.08 : 1.0)
                        .frame(width: 32, height: 26)

                    // Badge for Classify tab (Index 1)
                    if index == 1 && pendingCount > 0 {
                        Text("\(pendingCount)")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(Color(hex: "#061A13"))
                            .frame(width: 15, height: 15)
                            .background(Color(hex: "#00FF88"))
                            .clipShape(Circle())
                            .offset(x: 8, y: -4)
                            .shadow(color: Color(hex: "#00FF88").opacity(0.5), radius: 4)
                    }
                }

                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(
                        isSelected ? Color(hex: "#00E5FF") : Color.white.opacity(0.45)
                    )
            }
        }
        .buttonStyle(.plain)
    }

    // Center Elevated TRACK Button
    @ViewBuilder
    private func centerTrackButton(icon: String, label: String) -> some View {
        let isLive = trackerState == .activeTracking

        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                selected = 2
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    // Outer pulsing glowing ring
                    Circle()
                        .strokeBorder(Color(hex: "#00FF88").opacity(0.35), lineWidth: 2)
                        .frame(width: 52, height: 52)

                    // Glowing green elevated disc
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: isLive ?
                                    [Color(hex: "#FF3B30"), Color(hex: "#FF6259")] :
                                    [Color(hex: "#00FF88"), Color(hex: "#00D670")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .shadow(color: isLive ? Color(hex: "#FF3B30").opacity(0.5) : Color(hex: "#00FF88").opacity(0.55), radius: 10, x: 0, y: 3)

                    // Bolt icon
                    Image(systemName: isLive ? "waveform.path.ecg" : "bolt.fill")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(Color(hex: "#041B12"))
                }
                .offset(y: -8)

                Text(isLive ? "LIVE" : "TRACK")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(isLive ? Color(hex: "#FF3B30") : Color(hex: "#00FF88"))
                    .tracking(0.5)
                    .offset(y: -6)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Obsidian Precision Custom Toggle Style

struct ObsidianToggleStyle: ToggleStyle {
    var onColor: Color = Color(hex: "#00FF88")
    var offColor: Color = Color(hex: "#1E293B")

    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                configuration.isOn.toggle()
            }
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                // Outer Track
                Capsule()
                    .fill(
                        configuration.isOn
                            ? LinearGradient(
                                colors: [Color(hex: "#003820"), Color(hex: "#002418")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            : LinearGradient(
                                colors: [Color(hex: "#0B1520"), Color(hex: "#070D14")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                    )
                    .frame(width: 48, height: 26)
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                configuration.isOn
                                    ? LinearGradient(
                                        colors: [Color(hex: "#00FF88"), Color(hex: "#00E5FF").opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    : LinearGradient(
                                        colors: [Color.white.opacity(0.18), Color.white.opacity(0.08)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                lineWidth: 1.2
                            )
                    )
                    .shadow(
                        color: configuration.isOn ? Color(hex: "#00FF88").opacity(0.4) : Color.clear,
                        radius: 6,
                        x: 0,
                        y: 0
                    )

                // Glowing Thumb Knob
                Circle()
                    .fill(
                        configuration.isOn
                            ? LinearGradient(
                                colors: [Color(hex: "#00FFCC"), Color(hex: "#00FF88")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color(hex: "#718096"), Color(hex: "#4A5568")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .frame(width: 20, height: 20)
                    .padding(.horizontal, 3)
                    .shadow(
                        color: configuration.isOn ? Color(hex: "#00FF88").opacity(0.7) : Color.black.opacity(0.4),
                        radius: configuration.isOn ? 5 : 2,
                        x: 0,
                        y: 1
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AppTabView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
}
