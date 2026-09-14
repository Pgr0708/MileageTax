// RulesView.swift — MileageTax · Tab 5: Rules (Automations)
// Smart automation rules: Bluetooth gating, Work Hours auto-classify,
// geo-fence home/work, and IRS rate overrides.

import SwiftUI
import CoreData
import UserNotifications

struct RulesView: View {
    @StateObject private var bluetooth = BluetoothVehicleManager.shared

    // Centralized Settings (Single Source of Truth)
    @AppStorage(AppStorageKeys.autoClassifyWorkHours) private var autoClassifyWorkHours = false
    @AppStorage(AppStorageKeys.workHoursStart)        private var workHoursStart: Double = MileageTaxDefaults.defaultWorkStartHour
    @AppStorage(AppStorageKeys.workHoursEnd)          private var workHoursEnd:   Double = MileageTaxDefaults.defaultWorkEndHour
    @AppStorage(AppStorageKeys.irsRateOverride)       private var irsRateOverride: Double = MileageTaxDefaults.irsRatePerMile
    @AppStorage(AppStorageKeys.btGatingEnabled)       private var btGatingEnabled  = true
    @AppStorage(AppStorageKeys.notificationsEnabled)  private var notificationsOn  = true
    @AppStorage(AppStorageKeys.weeklyReportEnabled)   private var weeklyReportOn   = true

    @State private var showBTSetup     = false

    var body: some View {
        ZStack {
            backgroundLayer
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {
                    headerSection
                    btGatingSection
                    workHoursSection
                    irsRateSection
                    notificationsSection
                    dangerZone
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)
            }
        }
        .sheet(isPresented: $showBTSetup) { BluetoothSetupSheet() }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            Color.obsidian.ignoresSafeArea()
            RadialGradient(
                colors: [Color.deepPurple.opacity(0.06), .clear],
                center: .topLeading, startRadius: 0, endRadius: 280)
            .ignoresSafeArea()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Rules")
                    .font(.displayMedium)
                    .foregroundStyle(Color.textPrimary)
                Text("Smart Automations")
                    .font(.captionText)
                    .foregroundStyle(Color.deepPurple)
            }
            Spacer()
            Image(systemName: "brain.head.profile")
                .font(.system(size: 28))
                .foregroundStyle(AppGradient.purpleGradient)
        }
        .padding(.top, 8)
    }

    // MARK: - Bluetooth Gating

    private var btGatingSection: some View {
        ruleCard(
            icon: "antenna.radiowaves.left.and.right",
            title: "Bluetooth Vehicle Gating",
            subtitle: "Only track when connected to your car's Bluetooth",
            accentColor: .neonEmerald) {
            VStack(spacing: AppSpacing.md) {
                Toggle(isOn: $btGatingEnabled) {
                    HStack(spacing: AppSpacing.sm) {
                        Circle()
                            .fill(btGatingEnabled ? Color.neonEmerald : Color.textTertiary)
                            .frame(width: 8, height: 8)
                        Text("Enable BT Gating")
                            .font(.subheadline)
                            .foregroundStyle(Color.textPrimary)
                    }
                }
                .tint(Color.neonEmerald)

                if btGatingEnabled {
                    Divider().background(Color.glassBorder)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Connected Vehicle")
                                .font(.captionText)
                                .foregroundStyle(Color.textSecondary)
                            Text(bluetooth.connectedVehicleName ?? "None detected")
                                .font(.subheadline)
                                .foregroundStyle(bluetooth.isConnectedToVehicle
                                    ? Color.neonEmerald : Color.textTertiary)
                        }
                        Spacer()
                        Button("Manage") { showBTSetup = true }
                            .font(.captionText)
                            .foregroundStyle(Color.neonEmerald)
                    }

                    if !bluetooth.knownVehicleList.isEmpty {
                        HStack {
                            Image(systemName: "list.bullet")
                                .foregroundStyle(Color.textTertiary)
                                .font(.captionText)
                            Text(bluetooth.knownVehicleList.joined(separator: ", "))
                                .font(.captionText)
                                .foregroundStyle(Color.textSecondary)
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Work Hours Rule

    private var workHoursSection: some View {
        ruleCard(
            icon: "clock.badge.fill",
            title: "Work Hours Auto-Classify",
            subtitle: "Trips during work hours → Business",
            accentColor: .electricCyan) {
            VStack(spacing: AppSpacing.md) {
                Toggle(isOn: $autoClassifyWorkHours) {
                    Text("Enable Work Hours Rule")
                        .font(.subheadline)
                        .foregroundStyle(Color.textPrimary)
                }
                .tint(Color.electricCyan)

                if autoClassifyWorkHours {
                    Divider().background(Color.glassBorder)
                    VStack(spacing: AppSpacing.sm) {
                        HStack {
                            Text("Start Hour")
                                .font(.captionText)
                                .foregroundStyle(Color.textSecondary)
                            Spacer()
                            Text(String(format: "%.0f:00", workHoursStart))
                                .font(.captionText)
                                .foregroundStyle(Color.electricCyan)
                        }
                        Slider(value: $workHoursStart, in: 0...12, step: 1)
                            .tint(Color.electricCyan)

                        HStack {
                            Text("End Hour")
                                .font(.captionText)
                                .foregroundStyle(Color.textSecondary)
                            Spacer()
                            Text(String(format: "%.0f:00", workHoursEnd))
                                .font(.captionText)
                                .foregroundStyle(Color.electricCyan)
                        }
                        Slider(value: $workHoursEnd, in: 13...23, step: 1)
                            .tint(Color.electricCyan)
                    }
                }
            }
        }
    }

    // MARK: - IRS Rate

    private var irsRateSection: some View {
        ruleCard(
            icon: "dollarsign.circle.fill",
            title: "IRS Mileage Rate",
            subtitle: "Override the standard deduction rate",
            accentColor: .amberGlow) {
            VStack(spacing: AppSpacing.sm) {
                HStack {
                    Text("Rate per mile")
                        .font(.captionText)
                        .foregroundStyle(Color.textSecondary)
                    Spacer()
                    Text(String(format: "$%.3f", irsRateOverride))
                        .font(.monoLarge)
                        .font(.captionText)
                        .foregroundStyle(Color.amberGlow)
                }
                Slider(value: $irsRateOverride, in: 0.30...1.00, step: 0.005)
                    .tint(Color.amberGlow)

                HStack {
                    infoChip("2024 IRS: $0.670")
                    infoChip("2023 IRS: $0.655")
                    infoChip("Medical: $0.210")
                }
            }
        }
    }

    private func infoChip(_ text: String) -> some View {
        Button {
            let rate = Double(text.components(separatedBy: "$").last ?? "0.67") ?? 0.67
            irsRateOverride = rate
        } label: {
            Text(text)
                .font(.micro)
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                        .overlay(Capsule().strokeBorder(Color.glassBorder, lineWidth: 1)))
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        ruleCard(
            icon: "bell.badge.fill",
            title: "Notifications",
            subtitle: "Drive alerts, reminders, and weekly reports",
            accentColor: .deepPurple) {
            VStack(spacing: AppSpacing.sm) {
                Toggle(isOn: $notificationsOn) {
                    Label("Drive Alerts", systemImage: "car.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.textPrimary)
                }
                .tint(Color.deepPurple)

                Divider().background(Color.glassBorder)

                Toggle(isOn: $weeklyReportOn) {
                    Label("Weekly Summary (Sun 9AM)", systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(Color.textPrimary)
                }
                .tint(Color.deepPurple)
                .onChange(of: weeklyReportOn) { on in
                    if on { NotificationManager.shared.scheduleWeeklySummary() }
                    else {
                        UNUserNotificationCenter.current()
                            .removePendingNotificationRequests(withIdentifiers: ["weekly_summary"])
                    }
                }
            }
        }
    }

    // MARK: - Danger Zone

    private var dangerZone: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack {
                Text("Danger Zone")
                    .font(.captionText)
                    .foregroundStyle(Color.crimsonPulse)
                Spacer()
            }

            Button(role: .destructive) {
                clearAllTrips()
            } label: {
                Label("Clear All Trip Data", systemImage: "trash.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.crimsonPulse)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                            .fill(Color.crimsonPulse.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                                    .strokeBorder(Color.crimsonPulse.opacity(0.3), lineWidth: 1)))
            }
        }
    }

    private func clearAllTrips() {
        let ctx = CoreDataManager.shared.context
        let req = TripEntity.fetchRequest()
        if let trips = try? ctx.fetch(req) {
            trips.forEach { ctx.delete($0) }
            CoreDataManager.shared.save()
        }
    }

    // MARK: - Rule Card Builder

    private func ruleCard<Content: View>(
        icon: String,
        title: String,
        subtitle: String,
        accentColor: Color,
        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(accentColor.opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(accentColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(Color.textPrimary)
                    Text(subtitle)
                        .font(.captionText)
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer()
            }
            content()
        }
        .padding(AppSpacing.md)
        .glassCard(radius: AppRadius.md)
    }
}

