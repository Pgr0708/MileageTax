//
//  RulesView.swift
//  MileageTax · Tab 5: Automations & Rules
//  Obsidian Precision Design System · Exact Match to Spec
//

import SwiftUI
import CoreLocation
import CoreData
import UserNotifications

struct RulesView: View {
    @StateObject private var bluetooth = BluetoothVehicleManager.shared

    // Centralized Settings (Single Source of Truth)
    @AppStorage(AppStorageKeys.autoClassifyWorkHours) private var autoClassifyWorkHours = true
    @AppStorage(AppStorageKeys.workHoursStart)        private var workHoursStart: Double = 8.5
    @AppStorage(AppStorageKeys.workHoursEnd)          private var workHoursEnd:   Double = 17.5
    @AppStorage(AppStorageKeys.workDaysMask)          private var workDaysMask: Int = MileageTaxDefaults.defaultWorkDaysMask
    @AppStorage(AppStorageKeys.irsRateOverride)       private var irsRateOverride: Double        = MileageTaxDefaults.irsRatePerMile
    @AppStorage(AppStorageKeys.currencySymbol)          private var currencySymbol: String  = MileageTaxDefaults.defaultCurrencySymbol
    @AppStorage(AppStorageKeys.distanceUnit)            private var distanceUnit: String    = MileageTaxDefaults.defaultDistanceUnit
    @AppStorage(AppStorageKeys.btGatingEnabled)       private var btGatingEnabled  = true
    @AppStorage(AppStorageKeys.notificationsEnabled)  private var notificationsOn  = true
    @AppStorage(AppStorageKeys.weeklyReportEnabled)   private var weeklyReportOn   = true

    @StateObject private var geofenceManager = GeofenceManager.shared
    @StateObject private var rulesManager = AutomationRuleManager.shared
    @AppStorage(AppStorageKeys.geofenceEnabled) private var geofenceEnabled = true
    @AppStorage(AppStorageKeys.motionDetectDistanceM) private var detectDistanceM: Double = 300
    @AppStorage(AppStorageKeys.motionDetectSpeedMS) private var detectSpeedMS: Double = 5.0
    @State private var detectPreset: Int = {
        let d = UserDefaults.standard.double(forKey: AppStorageKeys.motionDetectDistanceM)
        let s = UserDefaults.standard.double(forKey: AppStorageKeys.motionDetectSpeedMS)
        if d > 0 {
            if d < 250 { return 0 }
            return s >= 6 ? 2 : 1
        }
        return 1   // default: 300 m / 18 km/h
    }()

    private var workShiftHoursFormatted: String {
        "\(Weekday.scheduleLabel(forMask: workDaysMask)) • \(Self.timeLabel(workHoursStart)) – \(Self.timeLabel(workHoursEnd))"
    }

    private static func timeLabel(_ hourValue: Double) -> String {
        let h = Int(hourValue)
        let m = Int((hourValue - Double(h)) * 60 + 0.5)
        let period = h >= 12 ? "PM" : "AM"
        let hour12 = h % 12 == 0 ? 12 : h % 12
        return String(format: "%d:%02d %@", hour12, m, period)
    }
    @State private var showAddRuleSheet = false
    @State private var showPinGeofenceSheet = false
    @State private var showWorkHoursSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background Scene with Alpine Scenic Wallpaper
                backgroundScene

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
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

                        // Card 5: Trip Detection Sensitivity
                        detectionSensitivityCard

                        Spacer(minLength: 110)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, Device.topSafeArea + 58) // safe area + header height
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddRuleSheet) {
                AddRuleModalView()
            }
            .sheet(isPresented: $showPinGeofenceSheet) {
                PinGeofenceModalView()
            }
            .sheet(isPresented: $showWorkHoursSheet) {
                WorkHoursModalView(startHour: $workHoursStart, endHour: $workHoursEnd, workDaysMask: $workDaysMask)
                    .presentationDetents([.medium, .large])
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Background Scene

    private var backgroundScene: some View {
        ZStack {
            Color(hex: "#06090E").ignoresSafeArea()

            // Mountain scenic wallpaper at top fading into deep obsidian
            Image("radar_bg_mountain")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color(hex: "#06090E").opacity(0.2),
                            Color(hex: "#06090E").opacity(0.85),
                            Color(hex: "#06090E")
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Top ambient teal aurora glow
            RadialGradient(
                colors: [Color(hex: "#00E5FF").opacity(0.12), Color.clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 280
            )
            .ignoresSafeArea()

            // Bottom-right neon emerald atmospheric glow
            RadialGradient(
                colors: [Color(hex: "#00FF88").opacity(0.08), Color.clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 360
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Screen Title Section

    private var screenTitleSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Automations")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    + Text(" & ")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "#00E5FF"))
                    + Text("Rules")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "#00FF88"))

                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(hex: "#00E5FF"))
                }

                Text("Eliminate manual logging forever\nwith surgical precision.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineSpacing(2)
            }

            Spacer()

            Button {
                showAddRuleSheet = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 13, weight: .bold))
                    Text("ADD\nRULE")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .multilineTextAlignment(.leading)
                }
                .foregroundStyle(Color(hex: "#00FF88"))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(hex: "#071E17").opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color(hex: "#00FF88").opacity(0.35), lineWidth: 1)
                )
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    // MARK: - Metrics Trio Row

    private var isLocationAlwaysAllowed: Bool {
        let status = CLLocationManager().authorizationStatus
        return status == .authorizedAlways
    }

    private var metricsTrioRow: some View {
        HStack(spacing: 8) {
            // 1. Passive State
            metricBadgeCard(
                icon: "waveform.path.ecg",
                header: "PASSIVE STATE",
                value: isLocationAlwaysAllowed ? "Active" : "Disabled",
                valueColor: isLocationAlwaysAllowed ? Color(hex: "#00FF88") : Color.red,
                sub: isLocationAlwaysAllowed ? "Zero manual tap" : "Needs 'Always' Auth"
            )

            // 2. Classification
            metricBadgeCard(
                icon: "chart.bar.fill",
                header: "CLASSIFICATION",
                value: "Enabled",
                valueColor: Color(hex: "#00E5FF"),
                sub: "Rule-based engine"
            )

            // 3. Sync Shield
            let hasSavedVehicle = !bluetooth.knownVehicleList.isEmpty
            metricBadgeCard(
                icon: "shield.lefthalf.filled",
                header: "SYNC SHIELD",
                value: hasSavedVehicle ? "HW-Gated" : "Inactive",
                valueColor: hasSavedVehicle ? .white : .gray,
                sub: bluetooth.connectedVehicleName ?? bluetooth.knownVehicleList.first ?? "No vehicle linked"
            )
        }
    }

    private func metricBadgeCard(icon: String, header: String, value: String, valueColor: Color, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color(hex: "#00E5FF"))
                Text(header)
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
            }

            Text(value)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(valueColor)

            Text(sub)
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(hex: "#0B121C").opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color(hex: "#00E5FF").opacity(0.35), Color(hex: "#00FF88").opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
    }

    // MARK: - Card Background with Precise Trailing Alignment
    struct RulesCardBackground: View {
        let imageName: String
        var aspectRatio: Double = 1024.0 / 377.0
        var trailingOffset: CGFloat = 0

        var body: some View {
            GeometryReader { geo in
                ZStack(alignment: .trailing) {
                    // Background artwork image pinned to trailing edge so right-side subject is 100% visible
                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(
                            width: max(geo.size.width, geo.size.height * aspectRatio),
                            height: geo.size.height,
                            alignment: .trailing
                        )
                        .offset(x: trailingOffset)
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .trailing)
                        .clipped()

                    // Protective obsidian glass gradient on left for crystal clear readability
                    LinearGradient(
                        stops: [
                            .init(color: Color(hex: "#060B14"), location: 0.0),
                            .init(color: Color(hex: "#060B14").opacity(0.96), location: 0.45),
                            .init(color: Color(hex: "#060B14").opacity(0.70), location: 0.58),
                            .init(color: Color.clear, location: 0.78)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
            }
        }
    }

    // MARK: - Card 1: Work Shift Schedule

    private var workShiftScheduleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Row
            HStack(alignment: .center, spacing: 8) {
                // Glowing Clock Icon
                ZStack {
                    Circle()
                        .fill(Color(hex: "#061A14").opacity(0.8))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color(hex: "#00FF88"), Color(hex: "#00E5FF").opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )

                    Image(systemName: "clock")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(hex: "#00FF88"))
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Work Shift")
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Schedule")
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(.white)
                }
                .fixedSize()

                Spacer()

                // SMART TIPS Pill
                HStack(spacing: 4) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(hex: "#00FF88"))
                    Text("SMART\nTIPS")
                        .font(.system(size: 7.5, weight: .black, design: .monospaced))
                        .foregroundStyle(Color(hex: "#00FF88"))
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color(hex: "#072018").opacity(0.9))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color(hex: "#00FF88").opacity(0.3), lineWidth: 1))

                // Toggle Switch
                Toggle("", isOn: $autoClassifyWorkHours)
                    .toggleStyle(ObsidianToggleStyle())
                    .labelsHidden()
            }

            // Schedule Days & Times
            Button {
                showWorkHoursSheet = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11, weight: .bold))
                    Text(workShiftHoursFormatted)
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    Image(systemName: "pencil")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(Color(hex: "#00FF88"))
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color(hex: "#00FF88").opacity(0.1))
                .clipShape(Capsule())
            }

            // Description — constrained to left side (~58% width) so the road/car on the right is fully visible
            (
                Text("Automatically classifies all drives initiated during registered shift hours as 100% ")
                    .foregroundStyle(.white.opacity(0.85))
                + Text("Tax-Deductible Business")
                    .foregroundStyle(Color(hex: "#00E5FF"))
                    .bold()
                + Text(" with verified timestamp telemetry.")
                    .foregroundStyle(.white.opacity(0.85))
            )
            .font(.system(size: 11, weight: .medium))
            .lineSpacing(2)
            .frame(maxWidth: 205, alignment: .leading)

            // Bottom Pills Row
            HStack(spacing: 8) {
                // Tags Pill
                HStack(spacing: 4) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 8.5))
                        .foregroundStyle(.white.opacity(0.6))
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Tags: #Consulting")
                        Text("#ClientRuns")
                    }
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(.white.opacity(0.75))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: "#08141F").opacity(0.85))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))

                Spacer()

                // Avg per week pill (dynamic status)
                HStack(spacing: 4) {
                    Image(systemName: autoClassifyWorkHours ? "checkmark.circle.fill" : "circle.dashed")
                        .font(.system(size: 9, weight: .bold))
                    Text(autoClassifyWorkHours ? "Status: Active" : "Status: Off")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(autoClassifyWorkHours ? Color(hex: "#00FF88") : Color.white.opacity(0.4))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(autoClassifyWorkHours ? Color(hex: "#072018").opacity(0.85) : Color.white.opacity(0.05))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(autoClassifyWorkHours ? Color(hex: "#00FF88").opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1))

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: "#00E5FF").opacity(0.6))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RulesCardBackground(imageName: "rules_workshift_bg"))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color(hex: "#00FF88").opacity(0.4), Color(hex: "#00E5FF").opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: Color.black.opacity(0.5), radius: 14, x: 0, y: 7)
    }

    // MARK: - Card 2: CarPlay & Bluetooth Sync

    private var carPlayBluetoothCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Row
            HStack(alignment: .center, spacing: 8) {
                // Glowing Car Icon
                ZStack {
                    Circle()
                        .fill(Color(hex: "#061520").opacity(0.8))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .strokeBorder(Color(hex: "#00E5FF").opacity(0.6), lineWidth: 1.5)
                        )

                    Image(systemName: "car.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(hex: "#00E5FF"))
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("CarPlay & Bluetooth")
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Sync")
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(.white)

                    Text(bluetooth.connectedVehicleName ?? "Not connected")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(bluetooth.connectedVehicleName != nil ? Color(hex: "#00E5FF") : Color.gray)
                        .padding(.top, 1)
                }
                .fixedSize()

                Spacer()

                Toggle("", isOn: $btGatingEnabled)
                    .toggleStyle(ObsidianToggleStyle())
                    .labelsHidden()
            }

            // Description — constrained to left side (~58% width) so steering wheel & Bluetooth HUD shine through
            Text("Strict hardware gate: only records mileage while connected to vehicle telemetry. Eliminates 100% of false positives from bus rides, trains, Uber trips, or walking.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .lineSpacing(2)
                .frame(maxWidth: 205, alignment: .leading)

            // Bottom Row
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(hex: "#00E5FF"))
                    Text("BT Beacon Latency")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                    Text(bluetooth.connectedVehicleName != nil ? "14ms • Active" : "Scanning...")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(bluetooth.connectedVehicleName != nil ? Color(hex: "#00E5FF") : Color.gray)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color(hex: "#071B24").opacity(0.85))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color(hex: "#00E5FF").opacity(0.25), lineWidth: 1))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: "#00E5FF").opacity(0.6))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RulesCardBackground(imageName: "rules_bluetooth_bg"))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color(hex: "#00E5FF").opacity(0.4), Color(hex: "#00FF88").opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: Color.black.opacity(0.5), radius: 14, x: 0, y: 7)
    }

    // MARK: - Card 3: Frequent Places Geofence

    private var frequentPlacesGeofenceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Row
            HStack(alignment: .center, spacing: 8) {
                // Glowing Pin Icon
                ZStack {
                    Circle()
                        .fill(Color(hex: "#061A14").opacity(0.8))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .strokeBorder(Color(hex: "#00FF88").opacity(0.6), lineWidth: 1.5)
                        )

                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color(hex: "#00FF88"))
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Frequent Places")
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Geofence")
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Proximity-triggered ledger tagging")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.top, 1)
                }
                .fixedSize()

                Spacer()

                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.fill")
                            .font(.system(size: 8))
                        Text("\(geofenceManager.savedZones.count) SAVED")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(Color(hex: "#00E5FF"))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#0B1D2C").opacity(0.85))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color(hex: "#00E5FF").opacity(0.3), lineWidth: 1))
                    .fixedSize()

                    Toggle("", isOn: $geofenceEnabled)
                        .toggleStyle(ObsidianToggleStyle())
                        .labelsHidden()
                }
            }

            // Places List — constrained to left side (~60% width) so the 3D map & glowing pins on the right show through
            VStack(spacing: 6) {
                ForEach(geofenceManager.savedZones) { zone in
                    geofencePlaceRow(
                        icon: zone.icon,
                        title: zone.title,
                        perimeterMeters: zone.perimeterMeters,
                        tag: zone.tag,
                        tagColor: Color(hex: zone.tagColorHex)
                    )
                }
            }
            .frame(maxWidth: 215, alignment: .leading)

            // Pin New Geofence Zone Button
            Button {
                showPinGeofenceSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "scope")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hex: "#00FF88"))
                    Text("Pin New Geofence Zone")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(Color(hex: "#0A1724").opacity(0.85))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color(hex: "#00E5FF").opacity(0.35), lineWidth: 1))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RulesCardBackground(imageName: "rules_geofence_bg"))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color(hex: "#00E5FF").opacity(0.4), Color(hex: "#00FF88").opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: Color.black.opacity(0.5), radius: 14, x: 0, y: 7)
    }

    private func geofencePlaceRow(icon: String, title: String, perimeterMeters: Double, tag: String, tagColor: Color) -> some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(hex: "#081E22").opacity(0.8))
                    .frame(width: 28, height: 28)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(hex: "#00FF88").opacity(0.25), lineWidth: 1))

                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: "#00FF88"))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text("\(Int(perimeterMeters))m zone")
                        .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)

                    Text("•")
                        .font(.system(size: 7))
                        .foregroundStyle(.white.opacity(0.3))

                    Text(tag)
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(tagColor)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(hex: "#080F17").opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
    }

    // MARK: - Card 4: CoreMotion Intelligent Gating

    private var coreMotionGatingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header Row
            HStack(alignment: .center, spacing: 8) {
                // Glowing Motion Phone Icon
                ZStack {
                    Circle()
                        .fill(Color(hex: "#061520").opacity(0.8))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .strokeBorder(Color(hex: "#00E5FF").opacity(0.6), lineWidth: 1.5)
                        )

                    Image(systemName: "iphone.motion")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(hex: "#00E5FF"))
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("CoreMotion Intelligent")
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Gating")
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Sub-Centimeter Hardware Telemetry")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "#00E5FF"))
                        .padding(.top, 1)
                }
                .fixedSize()

                Spacer()

                VStack(spacing: 1) {
                    Text("iOS 18")
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    Text("API")
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                }
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
            }

            // Comparison Bars — constrained to left side (~58% width) so 3D Holographic Chipset on the right shows through
            VStack(spacing: 8) {
                // MileageTax PRO
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        HStack(spacing: 5) {
                            Circle().fill(Color(hex: "#00FF88")).frame(width: 6, height: 6)
                            Text("MileageTax PRO")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        }

                        Spacer()

                        Text("1.1% / day")
                            .font(.system(size: 10.5, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Color(hex: "#00FF88"))
                    }

                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08)).frame(height: 5)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#00FF88"), Color(hex: "#00E5FF")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 120, height: 5)
                            .shadow(color: Color(hex: "#00FF88").opacity(0.5), radius: 3)
                    }
                }

                // Legacy Tracking Apps
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        HStack(spacing: 5) {
                            Circle().fill(Color.white.opacity(0.4)).frame(width: 6, height: 6)
                            Text("Legacy Tracking Apps")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                        }

                        Spacer()

                        Text("8.0% – 12.0% / day")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.45))
                    }

                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08)).frame(height: 5)
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 175, height: 5)
                    }
                }
            }
            .frame(maxWidth: 215, alignment: .leading)

            // Bottom explanation — constrained to left so it doesn't overlap the chip base
            Text("GPS chips remain completely unpowered until on-device accelerometer & gyroscope detect sustained vehicular acceleration patterns (>15 mph).")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
                .lineSpacing(2)
                .frame(maxWidth: 205, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RulesCardBackground(imageName: "rules_coremotion_bg"))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color(hex: "#00E5FF").opacity(0.4), Color(hex: "#00FF88").opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: Color.black.opacity(0.5), radius: 14, x: 0, y: 7)
    }

    // MARK: - Card 5: Trip Detection Sensitivity

    private var detectionSensitivityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(hex: "#00E5FF"))
                Text("Trip Detection")
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("DETECT AFTER")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Picker("", selection: $detectPreset) {
                Text("60 m / 5 km/h").tag(0)
                Text("300 m / 18 km/h").tag(1)
                Text("300 m / 24 km/h").tag(2)
            }
            .pickerStyle(.segmented)
            .onChange(of: detectPreset) { _, newVal in
                switch newVal {
                case 0:
                    detectDistanceM = 60
                    detectSpeedMS = 1.4   // 5 km/h
                case 2:
                    detectDistanceM = 300
                    detectSpeedMS = 6.7   // 24 km/h ≈ 15 mph
                default:
                    detectDistanceM = 300
                    detectSpeedMS = 5.0   // 18 km/h
                }
            }

            Text("A drive is recorded once you've moved this far at this speed — the trip's true start is still captured from the parked origin.")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .lineSpacing(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#0A1018").opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }
}

// MARK: - Modals

struct AddRuleModalView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var geofenceManager = GeofenceManager.shared
    @StateObject private var bluetooth = BluetoothVehicleManager.shared

    @State private var ruleName = ""
    @State private var ruleType: AutomationRuleType = .geofenceZone
    @State private var classification: TripClassification = .business
    @State private var businessPurpose = ""
    @State private var useSchedule = false
    @State private var selectedDays: Set<Weekday> = Weekday.monToFri
    @State private var startHour: Double = 9
    @State private var endHour: Double = 17
    @State private var selectedZoneIDs: Set<UUID> = []
    @State private var useRoute = false
    @State private var startZoneID: UUID?
    @State private var endZoneID: UUID?
    @State private var vehicleName = ""
    @State private var showPinZone = false

    private let purposeSuggestions = ["Client Meeting", "Site Inspection", "Office Commute", "Airport Run"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#06090E").ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        ruleField("RULE NAME", placeholder: "e.g. Client X HQ", text: $ruleName)

                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("AUTO-CLASSIFICATION")
                            Picker("", selection: $classification) {
                                Text("Business").tag(TripClassification.business)
                                Text("Personal").tag(TripClassification.personal)
                            }
                            .pickerStyle(.segmented)
                        }

                        ruleField("DEFAULT IRS PURPOSE", placeholder: "e.g. Client Meeting", text: $businessPurpose)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(purposeSuggestions, id: \.self) { s in
                                    Button { businessPurpose = s } label: {
                                        Text(s)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(Color(hex: "#00E5FF"))
                                            .padding(.horizontal, 10).padding(.vertical, 6)
                                            .background(Color(hex: "#00E5FF").opacity(0.1))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("TRIGGER TYPE")
                            Picker("", selection: $ruleType) {
                                Text("Geofence").tag(AutomationRuleType.geofenceZone)
                                Text("Work Hours").tag(AutomationRuleType.workHours)
                                Text("Bluetooth").tag(AutomationRuleType.bluetoothVehicle)
                            }
                            .pickerStyle(.segmented)
                        }

                        switch ruleType {
                        case .geofenceZone: zoneSection
                        case .workHours: scheduleSection
                        case .bluetoothVehicle:
                            ruleField("VEHICLE NAME", placeholder: "e.g. Prius", text: $vehicleName)
                        }

                        Button { save() } label: {
                            HStack {
                                Image(systemName: "bolt.fill")
                                Text("Save Automation Rule")
                            }
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color(hex: "#061A13"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(colors: [Color(hex: "#00FF88"), Color(hex: "#00E5FF")],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: Color(hex: "#00FF88").opacity(0.3), radius: 10, y: 4)
                        }
                        .padding(.top, 6)
                        .padding(.bottom, 12)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("New Rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color(hex: "#00E5FF"))
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color(hex: "#06090E"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showPinZone) { PinGeofenceModalView() }
        }
    }

    private var zoneSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("FREQUENT PLACES (ANY OF)")

            if geofenceManager.savedZones.isEmpty {
                Text("No saved places yet — pin one first.")
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.5))
            } else {
                ForEach(geofenceManager.savedZones) { zone in
                    Button {
                        if selectedZoneIDs.contains(zone.id) { selectedZoneIDs.remove(zone.id) }
                        else { selectedZoneIDs.insert(zone.id) }
                    } label: {
                        HStack {
                            Image(systemName: selectedZoneIDs.contains(zone.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedZoneIDs.contains(zone.id) ? Color(hex: "#00FF88") : .white.opacity(0.4))
                            Text(zone.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                            Spacer()
                            Text(zone.tag).font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
                        }
                        .padding(10)
                        .background(Color(hex: "#0C141E"))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }

            Button { showPinZone = true } label: {
                HStack { Image(systemName: "scope"); Text("Pin New Place") }
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(Color(hex: "#00FF88"))
                    .padding(.vertical, 8)
            }

            Toggle(isOn: $useRoute) {
                Text("Route (start → end)").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
            }
            .tint(Color(hex: "#00FF88"))

            if useRoute {
                HStack(spacing: 10) {
                    zonePicker("START", selection: $startZoneID)
                    zonePicker("END", selection: $endZoneID)
                }
            }
        }
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $useSchedule) {
                Text("Only during specific hours").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
            }
            .tint(Color(hex: "#00FF88"))

            if useSchedule {
                HStack(spacing: 8) {
                    ForEach(Weekday.allCases) { day in
                        let on = selectedDays.contains(day)
                        Button {
                            if on { selectedDays.remove(day) } else { selectedDays.insert(day) }
                        } label: {
                            Text(day.threeLetter)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(on ? Color(hex: "#061A13") : .white.opacity(0.7))
                                .frame(maxWidth: .infinity).frame(height: 38)
                                .background(on ? Color(hex: "#00FF88") : Color(hex: "#0E1622"))
                                .clipShape(RoundedRectangle(cornerRadius: 9))
                        }
                    }
                }

                DatePicker("START", selection: Binding(
                    get: { date(from: startHour) },
                    set: { startHour = hour(from: $0) }
                ), displayedComponents: .hourAndMinute).colorScheme(.dark).tint(Color(hex: "#00FF88"))

                DatePicker("END", selection: Binding(
                    get: { date(from: endHour) },
                    set: { endHour = hour(from: $0) }
                ), displayedComponents: .hourAndMinute).colorScheme(.dark).tint(Color(hex: "#00FF88"))
            }
        }
    }

    private func zonePicker(_ label: String, selection: Binding<UUID?>) -> some View {
        Menu {
            ForEach(geofenceManager.savedZones) { zone in
                Button(zone.title) { selection.wrappedValue = zone.id }
            }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(label).font(.system(size: 9, weight: .heavy, design: .monospaced)).foregroundStyle(.white.opacity(0.4))
                Text(geofenceManager.savedZones.first(where: { $0.id == selection.wrappedValue })?.title ?? "Any")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color(hex: "#0C141E"))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func save() {
        let name = ruleName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { dismiss(); return }
        let rule = AutomationRule(
            name: name,
            type: ruleType,
            classification: classification,
            businessPurpose: businessPurpose.trimmingCharacters(in: .whitespaces),
            weekdayMask: (ruleType == .workHours && useSchedule) ? Weekday.mask(from: selectedDays) : nil,
            startHour: (ruleType == .workHours && useSchedule) ? startHour : nil,
            endHour: (ruleType == .workHours && useSchedule) ? endHour : nil,
            zoneIDs: ruleType == .geofenceZone ? Array(selectedZoneIDs) : [],
            startZoneID: (ruleType == .geofenceZone && useRoute) ? startZoneID : nil,
            endZoneID: (ruleType == .geofenceZone && useRoute) ? endZoneID : nil,
            vehicleName: ruleType == .bluetoothVehicle ? vehicleName : nil,
            priority: 100
        )
        AutomationRuleManager.shared.addRule(rule)
        dismiss()
    }

    private func sectionLabel(_ s: String) -> some View {
        Text(s).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(Color(hex: "#00E5FF"))
    }

    private func ruleField(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel(label)
            TextField(placeholder, text: text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .padding()
                .background(Color(hex: "#0C141E"))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
    }

    private func date(from hourValue: Double) -> Date {
        let cal = Calendar.current
        return cal.date(bySettingHour: Int(hourValue), minute: Int((hourValue - Double(Int(hourValue))) * 60), second: 0, of: Date()) ?? Date()
    }

    private func hour(from date: Date) -> Double {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60.0
    }
}

struct PinGeofenceModalView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var placeName = ""
    @State private var radiusMeters = 150.0
    @State private var isPersonal = false
    @StateObject private var locationRequester = OneShotLocationRequester()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#06090E").ignoresSafeArea()
                
                RadialGradient(
                    colors: [Color(hex: "#00FF88").opacity(0.15), Color.clear],
                    center: .top,
                    startRadius: 10,
                    endRadius: 400
                ).ignoresSafeArea()

                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PLACE NAME")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(hex: "#00FF88"))
                            
                        TextField("e.g. Office, Client HQ", text: $placeName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                            .padding()
                            .background(Color(hex: "#0C141E"))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("PERIMETER RADIUS")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(hex: "#00FF88"))
                            Spacer()
                            Text("\(Int(radiusMeters)) meters")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                        }
                        
                        Slider(value: $radiusMeters, in: 50...500, step: 25)
                            .tint(Color(hex: "#00FF88"))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: $isPersonal) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("PERSONAL PLACE")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color(hex: "#FFB020"))
                                Text("Trips to/from here will be marked Personal")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                        .tint(Color(hex: "#7B4FFF"))

                        HStack(spacing: 6) {
                            Image(systemName: locationRequester.coordinate != nil ? "location.fill" : "location.slash")
                                .font(.system(size: 10))
                                .foregroundStyle(locationRequester.coordinate != nil ? Color(hex: "#00FF88") : .white.opacity(0.5))
                            Text(locationRequester.coordinate != nil ? "Center: current location" : "Center: default (Apple Park)")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }

                    Spacer()

                    Button {
                        if !placeName.trimmingCharacters(in: .whitespaces).isEmpty {
                            let coord = locationRequester.coordinate
                            GeofenceManager.shared.addZone(
                                title: placeName,
                                perimeterMeters: radiusMeters,
                                tag: "#Custom Zone",
                                tagColorHex: isPersonal ? "#7B4FFF" : "#00FF88",
                                icon: "mappin.circle.fill",
                                isPersonal: isPersonal,
                                latitude: coord?.latitude ?? 37.7749,
                                longitude: coord?.longitude ?? -122.4194
                            )
                        }
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "mappin.and.ellipse")
                            Text("Save Geofence")
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(hex: "#061A13"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: "#00FF88"))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color(hex: "#00FF88").opacity(0.3), radius: 10, y: 4)
                    }
                    .padding(.bottom, 8)
                }
                .padding(20)
            }
            .navigationTitle("Pin Geofence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color(hex: "#00FF88"))
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color(hex: "#06090E"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear { locationRequester.request() }
        }
    }
}

struct WorkHoursModalView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var startHour: Double
    @Binding var endHour: Double
    @Binding var workDaysMask: Int
    
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var selectedDays: Set<Weekday> = Weekday.monToFri
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#06090E").ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Weekday selector (Mon–Sun, Mon–Fri selected by default)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("WORK DAYS")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(hex: "#00FF88"))
                            Spacer()
                            Text(Weekday.scheduleLabel(forMask: Weekday.mask(from: selectedDays)))
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white.opacity(0.6))
                        }

                        HStack(spacing: 8) {
                            ForEach(Weekday.allCases) { day in
                                let selected = selectedDays.contains(day)
                                Button {
                                    if selected { selectedDays.remove(day) } else { selectedDays.insert(day) }
                                } label: {
                                    Text(day.threeLetter)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(selected ? Color(hex: "#061A13") : .white.opacity(0.7))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 40)
                                        .background(selected ? Color(hex: "#00FF88") : Color(hex: "#0E1622"))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(
                                            selected ? Color.clear : Color.white.opacity(0.08)))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        HStack(spacing: 10) {
                            quickDayButton("Weekdays") { selectedDays = Weekday.monToFri }
                            quickDayButton("Every day") { selectedDays = Set(Weekday.allCases) }
                            quickDayButton("Clear") { selectedDays = [] }
                        }
                    }
                    .padding(16)
                    .background(Color(hex: "#0A1018").opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))

                    VStack(alignment: .leading, spacing: 12) {
                        DatePicker("START TIME", selection: $startDate, displayedComponents: .hourAndMinute)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(hex: "#00FF88"))
                            .colorScheme(.dark)
                            .tint(Color(hex: "#00FF88"))
                            .onChange(of: startDate) { newValue in
                                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                                startHour = Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60.0
                            }
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        DatePicker("END TIME", selection: $endDate, displayedComponents: .hourAndMinute)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(hex: "#00FF88"))
                            .colorScheme(.dark)
                            .tint(Color(hex: "#00FF88"))
                            .onChange(of: endDate) { newValue in
                                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                                endHour = Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60.0
                            }
                    }
                    .padding(20)
                    .background(Color(hex: "#0A1018").opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                    
                    Spacer()
                    
                    Button {
                        workDaysMask = Weekday.mask(from: selectedDays)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Save Schedule")
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(hex: "#061A13"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: "#00FF88"))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color(hex: "#00FF88").opacity(0.3), radius: 10, y: 4)
                    }
                    .padding(.bottom, 8)
                }
                .padding(24)
                .padding(.top, 16)
            }
            .navigationTitle("Edit Shift Hours")
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
            .onAppear {
                let cal = Calendar.current
                startDate = cal.date(bySettingHour: Int(startHour), minute: Int((startHour.truncatingRemainder(dividingBy: 1)) * 60), second: 0, of: Date()) ?? Date()
                endDate = cal.date(bySettingHour: Int(endHour), minute: Int((endHour.truncatingRemainder(dividingBy: 1)) * 60), second: 0, of: Date()) ?? Date()
                selectedDays = Weekday.weekdays(fromMask: workDaysMask)
            }
        }
    }

    private func quickDayButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(hex: "#00E5FF"))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(hex: "#00E5FF").opacity(0.08))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color(hex: "#00E5FF").opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
