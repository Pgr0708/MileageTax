//
//  RulesView.swift
//  MileageTax · Tab 5: Automations & Rules
//  Obsidian Precision Design System · Exact Match to Spec
//

import SwiftUI
import CoreData
import UserNotifications

struct RulesView: View {
    @StateObject private var bluetooth = BluetoothVehicleManager.shared

    // Centralized Settings (Single Source of Truth)
    @AppStorage(AppStorageKeys.autoClassifyWorkHours) private var autoClassifyWorkHours = true
    @AppStorage(AppStorageKeys.workHoursStart)        private var workHoursStart: Double = 8.5
    @AppStorage(AppStorageKeys.workHoursEnd)          private var workHoursEnd:   Double = 17.5
    @AppStorage(AppStorageKeys.irsRateOverride)       private var irsRateOverride: Double = MileageTaxDefaults.irsRatePerMile
    @AppStorage(AppStorageKeys.btGatingEnabled)       private var btGatingEnabled  = true
    @AppStorage(AppStorageKeys.notificationsEnabled)  private var notificationsOn  = true
    @AppStorage(AppStorageKeys.weeklyReportEnabled)   private var weeklyReportOn   = true

    @StateObject private var geofenceManager = GeofenceManager.shared
    @StateObject private var rulesManager = AutomationRuleManager.shared
    @AppStorage("MT_geofenceEnabled") private var geofenceEnabled = true

    private var workShiftHoursFormatted: String {
        let startH = Int(workHoursStart)
        let startM = Int((workHoursStart.truncatingRemainder(dividingBy: 1)) * 60)
        let endH = Int(workHoursEnd)
        let endM = Int((workHoursEnd.truncatingRemainder(dividingBy: 1)) * 60)
        let sFmt = String(format: "%d:%02d AM", startH > 12 ? startH - 12 : startH, startM)
        let eFmt = String(format: "%d:%02d PM", endH > 12 ? endH - 12 : endH, endM)
        return "Mon–Fri • \(sFmt) – \(eFmt)"
    }
    @State private var showAddRuleSheet = false
    @State private var showPinGeofenceSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(hex: "#06090E").ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Top Header Bar
                        topHeaderBar

                        // Title & Add Rule Header
                        screenTitleSection

                        // 3 Metric Badges Row
                        metricsTrioRow

                        // Card 1: Work Shift Schedule
                        workShiftScheduleCard

                        // Card 2: CarPlay & Bluetooth Sync
                        carPlayBluetoothCard

                        // Card 3: Frequent Places Geofence
                        frequentPlacesGeofenceCard

                        // Card 4: CoreMotion Intelligent Gating
                        coreMotionGatingCard

                        Spacer(minLength: 110)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showAddRuleSheet) {
            AddRuleModalView()
        }
        .sheet(isPresented: $showPinGeofenceSheet) {
            PinGeofenceModalView()
        }
    }

    // MARK: - Top Header Bar

    private var topHeaderBar: some View {
        HStack {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(hex: "#0C141E"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color(hex: "#00E5FF").opacity(0.4), lineWidth: 1)
                        )
                        .frame(width: 36, height: 36)

                    Image(systemName: "m.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#00E5FF"), Color(hex: "#00FF88")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text("MileageTax")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("PRO")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(Color(hex: "#00E5FF"))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#00E5FF").opacity(0.12))
                            .clipShape(Capsule())
                    }
                    Text("● 1.1%/HR COREMOTION")
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Color(hex: "#00FF88").opacity(0.8))
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button {} label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }

                Button {} label: {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color(hex: "#00FF88"))
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Screen Title Section

    private var screenTitleSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Automations & Rules")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(hex: "#00E5FF"))
                }

                Text("Eliminate manual logging forever with surgical precision")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer()

            Button {
                showAddRuleSheet = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("ADD\nRULE")
                        .font(.system(size: 9.5, weight: .black, design: .rounded))
                        .multilineTextAlignment(.leading)
                }
                .foregroundStyle(Color(hex: "#00FF88"))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(hex: "#0A2018").opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color(hex: "#00FF88").opacity(0.35), lineWidth: 1)
                )
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Metrics Trio Row

    private var metricsTrioRow: some View {
        HStack(spacing: 8) {
            // 1. Passive State
            metricBadgeCard(
                header: "PASSIVE STATE",
                value: "Active",
                valueColor: Color(hex: "#00FF88"),
                sub: "Zero manual tap"
            )

            // 2. Classification
            metricBadgeCard(
                header: "CLASSIFICATION",
                value: "98.7%",
                valueColor: Color(hex: "#00E5FF"),
                sub: "Auto-confidence"
            )

            // 3. Sync Shield
            metricBadgeCard(
                header: "SYNC SHIELD",
                value: "HW-Gated",
                valueColor: .white,
                sub: bluetooth.connectedVehicleName ?? "Prius 2024"
            )
        }
    }

    private func metricBadgeCard(header: String, value: String, valueColor: Color, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(header)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))

            Text(value)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(valueColor)

            Text(sub)
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(hex: "#0B121C").opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
    }

    // MARK: - Card 1: Work Shift Schedule

    private var workShiftScheduleCard: some View {
        VStack(spacing: 12) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: "#0A241C"))
                        .frame(width: 36, height: 36)
                    Image(systemName: "clock.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(hex: "#00FF88"))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Work Shift Schedule")
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(.white)
                    Text(workShiftHoursFormatted)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "#00E5FF"))
                }

                Spacer()

                HStack(spacing: 6) {
                    Text("SMART\nIRS")
                        .font(.system(size: 7.5, weight: .black, design: .monospaced))
                        .foregroundStyle(Color(hex: "#00FF88"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color(hex: "#00FF88").opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    Toggle("", isOn: $autoClassifyWorkHours)
                        .tint(Color(hex: "#00FF88"))
                        .labelsHidden()
                }
            }

            Text("Automatically classifies all drives initiated during registered shift hours as 100% Tax-Deductible Business with verified timestamp telemetry.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .lineSpacing(2)

            HStack(spacing: 10) {
                // Tags
                HStack(spacing: 4) {
                    Image(systemName: "newspaper.fill")
                        .font(.system(size: 9))
                    Text("Tags: #Consulting #ClientRuns")
                        .font(.system(size: 9.5, weight: .bold))
                }
                .foregroundStyle(.white.opacity(0.75))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())

                Spacer()

                // Avg per week
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9, weight: .black))
                    Text("Avg: +$142.80/wk")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(Color(hex: "#00FF88"))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color(hex: "#071F17"))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color(hex: "#00FF88").opacity(0.25), lineWidth: 1))
            }
        }
        .padding(14)
        .background(Color(hex: "#0A1018").opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Card 2: CarPlay & Bluetooth Sync

    private var carPlayBluetoothCard: some View {
        VStack(spacing: 12) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: "#0C1F26"))
                        .frame(width: 36, height: 36)
                    Image(systemName: "car.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(hex: "#00E5FF"))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("CarPlay & Bluetooth Sync")
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Prius 2024 CarPlay [98:21]")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "#00E5FF"))
                }

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: "#00E5FF"))
                        .frame(width: 6, height: 6)
                        .shadow(color: Color(hex: "#00E5FF"), radius: 3)

                    Toggle("", isOn: $btGatingEnabled)
                        .tint(Color(hex: "#00FF88"))
                        .labelsHidden()
                }
            }

            Text("Strict hardware gate: only records mileage while connected to vehicle telemetry. Eliminates 100% of false positives from bus rides, trains, Uber trips, or walking.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .lineSpacing(2)

            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(hex: "#00FF88"))
                    Text("BT Beacon Latency")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                    Text("14ms • Standby")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "#00E5FF"))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.05))
                .clipShape(Capsule())

                Spacer()
            }
        }
        .padding(14)
        .background(Color(hex: "#0A1018").opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Card 3: Frequent Places Geofence

    private var frequentPlacesGeofenceCard: some View {
        VStack(spacing: 12) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: "#0C241E"))
                        .frame(width: 36, height: 36)
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(hex: "#00FF88"))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Frequent Places Geofence")
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Proximity-triggered ledger tagging")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                HStack(spacing: 6) {
                    Text("\(geofenceManager.savedZones.count) SAVED")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())

                    Toggle("", isOn: $geofenceEnabled)
                        .tint(Color(hex: "#00FF88"))
                        .labelsHidden()
                }
            }

            // Places List
            VStack(spacing: 8) {
                ForEach(geofenceManager.savedZones) { zone in
                    geofencePlaceRow(
                        icon: zone.icon,
                        title: zone.title,
                        perimeter: "\(Int(zone.perimeterMeters))m perimeter",
                        tag: zone.tag,
                        tagColor: Color(hex: zone.tagColorHex)
                    )
                }
            }

            // Pin New Geofence Zone Button
            Button {
                showPinGeofenceSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 11, weight: .bold))
                    Text("Pin New Geofence Zone")
                        .font(.system(size: 11.5, weight: .bold))
                }
                .foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(hex: "#0F1622").opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
            }
        }
        .padding(14)
        .background(Color(hex: "#0A1018").opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func geofencePlaceRow(icon: String, title: String, perimeter: String, tag: String, tagColor: Color) -> some View {
        HStack {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(.white)

                HStack(spacing: 4) {
                    Text(perimeter)
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                    Text("•")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.3))
                    Text(tag)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(tagColor)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(8)
        .background(Color(hex: "#080F17").opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Card 4: CoreMotion Intelligent Gating

    private var coreMotionGatingCard: some View {
        VStack(spacing: 12) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: "#0B221B"))
                        .frame(width: 36, height: 36)
                    Image(systemName: "figure.walk.motion")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(hex: "#00FF88"))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("CoreMotion Intelligent Gating")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Sub-Centimeter Hardware Telemetry")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "#00FF88"))
                }

                Spacer()

                Text("iOS 18 API")
                    .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
            }

            // Comparison Bars
            VStack(spacing: 8) {
                // MileageTax PRO
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Circle().fill(Color(hex: "#00FF88")).frame(width: 6, height: 6)
                        Text("MileageTax PRO")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    Text("1.1% / day")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "#00FF88"))
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.06))
                        Capsule()
                            .fill(Color(hex: "#00FF88"))
                            .frame(width: geo.size.width * 0.12)
                    }
                }
                .frame(height: 6)

                // Legacy Tracking Apps
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Circle().fill(Color.white.opacity(0.4)).frame(width: 6, height: 6)
                        Text("Legacy Tracking Apps")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    Spacer()

                    Text("8.0% – 12.6% / day")
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.06))
                        Capsule()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: geo.size.width * 0.78)
                    }
                }
                .frame(height: 6)
            }

            Text("GPS chips remain completely unpowered until on-device accelerometer & gyroscope detect sustained vehicular acceleration patterns (> 15 mph).")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
                .lineSpacing(2)
        }
        .padding(14)
        .background(Color(hex: "#0A1018").opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }
}

// MARK: - Modals

struct AddRuleModalView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var ruleName = ""
    @State private var ruleType = "Work Hours"

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#06090E").ignoresSafeArea()

                VStack(spacing: 16) {
                    TextField("Rule Name (e.g. Weekend Personal Drives)", text: $ruleName)
                        .padding()
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)

                    Picker("Type", selection: $ruleType) {
                        Text("Work Hours").tag("Work Hours")
                        Text("Geofence Zone").tag("Geofence Zone")
                        Text("Bluetooth Vehicle").tag("Bluetooth Vehicle")
                    }
                    .pickerStyle(.segmented)

                    Spacer()

                    Button {
                        if !ruleName.trimmingCharacters(in: .whitespaces).isEmpty {
                            let type = AutomationRuleType(rawValue: ruleType) ?? .workHours
                            AutomationRuleManager.shared.addRule(name: ruleName, type: type)
                        }
                        dismiss()
                    } label: {
                        Text("Save Automation Rule")
                            .font(.headline)
                            .foregroundStyle(Color(hex: "#061A13"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(hex: "#00FF88"))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(16)
            }
            .navigationTitle("New Automation Rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct PinGeofenceModalView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var placeName = ""
    @State private var radiusMeters = 150.0

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#06090E").ignoresSafeArea()

                VStack(spacing: 16) {
                    TextField("Place Name (e.g. Office, Client HQ)", text: $placeName)
                        .padding()
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Perimeter Radius: \(Int(radiusMeters)) meters")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                        Slider(value: $radiusMeters, in: 50...500, step: 25)
                            .tint(Color(hex: "#00FF88"))
                    }

                    Spacer()

                    Button {
                        if !placeName.trimmingCharacters(in: .whitespaces).isEmpty {
                            GeofenceManager.shared.addZone(
                                title: placeName,
                                perimeterMeters: radiusMeters,
                                tag: "#Custom Zone",
                                tagColorHex: "#00FF88",
                                icon: "mappin.circle.fill",
                                isPersonal: false
                            )
                        }
                        dismiss()
                    } label: {
                        Text("Save Geofence")
                            .font(.headline)
                            .foregroundStyle(Color(hex: "#061A13"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(hex: "#00FF88"))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(16)
            }
            .navigationTitle("Pin Geofence Zone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
