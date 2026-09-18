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
    @AppStorage(AppStorageKeys.irsRateOverride)       private var irsRateOverride: Double        = MileageTaxDefaults.irsRatePerMile
    @AppStorage(AppStorageKeys.currencySymbol)          private var currencySymbol: String  = MileageTaxDefaults.defaultCurrencySymbol
    @AppStorage(AppStorageKeys.distanceUnit)            private var distanceUnit: String    = MileageTaxDefaults.defaultDistanceUnit
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
                WorkHoursModalView(startHour: $workHoursStart, endHour: $workHoursEnd)
                    .presentationDetents([.height(360), .medium])
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
                
                // Subtle ambient glow
                RadialGradient(
                    colors: [Color(hex: "#00E5FF").opacity(0.15), Color.clear],
                    center: .top,
                    startRadius: 10,
                    endRadius: 400
                ).ignoresSafeArea()

                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("RULE NAME")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(hex: "#00E5FF"))
                        
                        TextField("e.g. Weekend Personal Drives", text: $ruleName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                            .padding()
                            .background(Color(hex: "#0C141E"))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("TRIGGER TYPE")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(hex: "#00E5FF"))
                            
                        Picker("Type", selection: $ruleType) {
                            Text("Work Hours").tag("Work Hours")
                            Text("Geofence Zone").tag("Geofence Zone")
                            Text("Bluetooth Vehicle").tag("Bluetooth Vehicle")
                        }
                        .pickerStyle(.segmented)
                        .colorMultiply(Color(hex: "#00E5FF").opacity(0.8)) // Tint the segmented control
                    }

                    Spacer()

                    Button {
                        if !ruleName.trimmingCharacters(in: .whitespaces).isEmpty {
                            let type = AutomationRuleType(rawValue: ruleType) ?? .workHours
                            AutomationRuleManager.shared.addRule(name: ruleName, type: type)
                        }
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "bolt.fill")
                            Text("Save Automation Rule")
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(hex: "#061A13"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#00FF88"), Color(hex: "#00E5FF")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color(hex: "#00FF88").opacity(0.3), radius: 10, y: 4)
                    }
                    .padding(.bottom, 8)
                }
                .padding(20)
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
        }
    }
}

struct WorkHoursModalView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var startHour: Double
    @Binding var endHour: Double
    
    @State private var startDate = Date()
    @State private var endDate = Date()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#06090E").ignoresSafeArea()
                
                VStack(spacing: 32) {
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
            }
        }
    }
}
