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

    // Centralized header state (shared across all tabs)
    @State private var showNotificationSheet: Bool = false
    @State private var showProfile: Bool = false

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TripEntity.startDate, ascending: false)],
        predicate: NSPredicate(format: "needsReview == true AND isInProgress == false"),
        animation: .default)
    private var pendingTrips: FetchedResults<TripEntity>
    private var pendingCount: Int { pendingTrips.count }

    var body: some View {
        ZStack(alignment: .bottom) {
            // ── Content (Direct Switch with smooth crossfade animation) ──────
            ZStack {
                RadarView(selectedTab: $selectedTab)
                    .tabPage(isActive: selectedTab == 0)
                    .allowsHitTesting(selectedTab == 0)

                ClassifyView(preselectedTripID: $classifyTripID)
                    .tabPage(isActive: selectedTab == 1)
                    .allowsHitTesting(selectedTab == 1)

                TrackView(selectedTab: $selectedTab)
                    .tabPage(isActive: selectedTab == 2)
                    .allowsHitTesting(selectedTab == 2)

                VaultView()
                    .tabPage(isActive: selectedTab == 3)
                    .allowsHitTesting(selectedTab == 3)

                RulesView()
                    .tabPage(isActive: selectedTab == 4)
                    .allowsHitTesting(selectedTab == 4)
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.85), value: selectedTab)
            .ignoresSafeArea()

            // ── Centralized Top Header Bar (overlaid above all tab content) ──
            VStack {
                SharedHeaderBar(
                    showNotificationSheet: $showNotificationSheet,
                    showProfile: $showProfile,
                    pendingCount: pendingCount
                )
                .padding(.horizontal, 16)
                .padding(.top, Device.topSafeArea)
                .padding(.bottom, 10)
                .background {
                    ZStack(alignment: .bottom) {
                        // Opaque + blurred backdrop so scrolled content never bleeds through.
                        Rectangle().fill(Color(hex: "#06090E").opacity(0.9))
                        Rectangle().fill(.ultraThinMaterial)
                        // Hard bottom edge + hairline for a crisp boundary.
                        Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
                    }
                    .ignoresSafeArea(edges: .top)
                }
                .shadow(color: Color.black.opacity(0.5), radius: 10, y: 6)
                Spacer()
            }
            .ignoresSafeArea()
            .allowsHitTesting(true)

            // ── Custom Tab Bar ────────────────────────────────────────────────
            // Scrim so scrolled content never shows below / around the floating bar.
            VStack {
                Spacer()
                LinearGradient(colors: [DS.bg.opacity(0), DS.bg.opacity(0.94), DS.bg],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 130 + Device.bottomSafeArea)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            CustomTabBar(selected: $selectedTab, trackerState: tracker.state)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
        }
        .background(Color.obsidian.ignoresSafeArea())
        .preferredColorScheme(.dark)
        // Notification Sheet
        .sheet(isPresented: $showNotificationSheet) {
            NotificationsSheetView(pendingCount: pendingCount)
        }
        // Profile as full-screen cover (outside individual NavigationStacks)
        .fullScreenCover(isPresented: $showProfile) {
            ProfileView()
        }
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
    @Namespace private var selection

    private let items: [(icon: String, label: String)] = [
        ("scope", "Radar"),
        ("doc.text", "Classify"),
        ("chevron.up.2", "TRACK"),
        ("lock.rectangle", "Vault"),
        ("gearshape", "Rules"),
    ]

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Spacer(minLength: 0)
                if index == 2 {
                    // Center Elevated Neon TRACK Button
                    centerTrackButton(icon: item.icon, label: item.label)
                } else {
                    regularTabButton(index: index, icon: item.icon, label: item.label)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background {
            ZStack {
                TabBarShape().fill(.ultraThinMaterial)
                TabBarShape().fill(LinearGradient(colors: [Color(hex: "#0B1620").opacity(0.92), Color(hex: "#04070B").opacity(0.96)],
                                                  startPoint: .top, endPoint: .bottom))
                TabBarShape().fill(RadialGradient(colors: [DS.cyan.opacity(0.16), .clear], center: .bottom, startRadius: 0, endRadius: 170))
            }
            .overlay(TabBarShape().stroke(
                LinearGradient(colors: [DS.cyan.opacity(0.55), DS.green.opacity(0.25), Color.white.opacity(0.06)],
                               startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2))
            .shadow(color: .black.opacity(0.65), radius: 18, y: 6)
        }
    }

    // Regular Tab Button
    @ViewBuilder
    private func regularTabButton(index: Int, icon: String, label: String) -> some View {
        let isSelected = selected == index
        let pendingCount = pendingTrips.count

        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) { selected = index }
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 19, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(
                            isSelected ?
                                AnyShapeStyle(DS.cyan) :
                                AnyShapeStyle(Color.white.opacity(0.45))
                        )
                        .scaleEffect(isSelected ? 1.08 : 1.0)
                        .frame(width: 32, height: 26)

                    // Badge for Classify tab (Index 1)
                    if index == 1 && pendingCount > 0 {
                        Text("\(pendingCount)")
                            .font(.system(size: 8.5, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 16, height: 16)
                            .background(DS.danger)
                            .clipShape(Circle())
                            .offset(x: 9, y: -4)
                            .shadow(color: DS.danger.opacity(0.6), radius: 4)
                    }
                }

                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundStyle(
                        isSelected ? DS.cyan : Color.white.opacity(0.45)
                    )

                // Active pill slides between tabs
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(DS.brandGradient)
                            .frame(width: 18, height: 3)
                            .shadow(color: DS.cyan, radius: 4)
                            .matchedGeometryEffect(id: "pill", in: selection)
                    }
                }
                .frame(height: 3)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // Center Elevated TRACK Button
    @ViewBuilder
    private func centerTrackButton(icon: String, label: String) -> some View {
        let isLive = trackerState == .activeTracking

        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            selected = 2
        } label: {
            let ring = isLive ? DS.danger : DS.cyan
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: "#0F2430"), DS.bg], center: .center, startRadius: 2, endRadius: 36))
                Circle()
                    .strokeBorder(ring, lineWidth: 2.5)
                    .shadow(color: ring, radius: isLive ? 12 : 8)
                Circle()
                    .strokeBorder(ring.opacity(0.25), lineWidth: 1)
                    .padding(-6)
                VStack(spacing: 1) {
                    Image(systemName: isLive ? "waveform.path.ecg" : icon)
                        .font(.system(size: 17, weight: .bold))
                    Text(isLive ? "LIVE" : label)
                        .font(DS.display(9))
                        .tracking(0.5)
                }
                .foregroundStyle(isLive ? DS.danger : .white)
            }
            .frame(width: 62, height: 62)
            .offset(y: -14)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tab bar shape (rounded bar with a curved notch cradling TRACK)

struct TabBarShape: Shape {
    var radius: CGFloat = 26
    var notchWidth: CGFloat = 92
    var notchDepth: CGFloat = 20

    func path(in r: CGRect) -> Path {
        let mid = r.midX, half = notchWidth / 2
        var p = Path()
        p.move(to: CGPoint(x: r.minX + radius, y: r.minY))
        p.addLine(to: CGPoint(x: mid - half - 14, y: r.minY))
        p.addCurve(to: CGPoint(x: mid, y: r.minY + notchDepth),
                   control1: CGPoint(x: mid - half + 8, y: r.minY),
                   control2: CGPoint(x: mid - half + 10, y: r.minY + notchDepth))
        p.addCurve(to: CGPoint(x: mid + half + 14, y: r.minY),
                   control1: CGPoint(x: mid + half - 10, y: r.minY + notchDepth),
                   control2: CGPoint(x: mid + half - 8, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - radius, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + radius), control: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - radius))
        p.addQuadCurve(to: CGPoint(x: r.maxX - radius, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + radius, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - radius), control: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + radius))
        p.addQuadCurve(to: CGPoint(x: r.minX + radius, y: r.minY), control: CGPoint(x: r.minX, y: r.minY))
        p.closeSubpath()
        return p
    }
}

private extension View {
    /// Inactive tabs recede (fade, slight zoom-out, blur); the active one settles in.
    func tabPage(isActive: Bool) -> some View {
        self.opacity(isActive ? 1 : 0)
            .scaleEffect(isActive ? 1 : 0.97)
            .blur(radius: isActive ? 0 : 8)
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
