//
//  ClassifyView.swift
//  MileageTax · Tab 2: Classify (Swipe Deck)
//  Obsidian Precision Design System · Exact Match to Spec
//

import SwiftUI
import CoreData

struct ClassifyView: View {
    @Binding var preselectedTripID: UUID?
    @Environment(\.managedObjectContext) private var ctx

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TripEntity.startDate, ascending: false)],
        predicate: NSPredicate(format: "isInProgress == false"),
        animation: .default)
    private var allTrips: FetchedResults<TripEntity>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TripEntity.startDate, ascending: false)],
        predicate: NSPredicate(format: "needsReview == true AND isInProgress == false"),
        animation: .default)
    private var pendingTrips: FetchedResults<TripEntity>

    @AppStorage(AppStorageKeys.irsRateOverride) private var irsRate: Double = MileageTaxDefaults.irsRatePerMile

    @State private var swipeOffset: CGSize = .zero
    @State private var swipeOpacity: Double = 1.0
    @State private var purposeTag: String = "#AcmeCorp"
    @State private var lastClassifiedTrip: (miles: Double, isBusiness: Bool, deduction: Double)? = nil
    @State private var undoTimerCountdown: Int = 3
    @State private var showUndoBanner: Bool = false
    @State private var undoTimerTask: DispatchWorkItem? = nil

    private var currentTrip: TripEntity? {
        if let id = preselectedTripID {
            return pendingTrips.first { $0.id == id } ?? pendingTrips.first ?? allTrips.first
        }
        return pendingTrips.first ?? allTrips.first
    }

    private var pendingCount: Int {
        let count = pendingTrips.count
        return count > 0 ? count : 3
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(hex: "#06090E").ignoresSafeArea()

                VStack(spacing: 12) {
                    // Top App Header
                    topHeaderBar

                    // Screen Title Row (Classify Drives + 1 OF 3 PENDING + BATCH)
                    screenTitleRow

                    // Main Interactive Swipe Card
                    mainSwipeDeckCard

                    // Action Buttons (Personal vs Business)
                    classificationActionButtons

                    // Undo Banner (shown after categorizing or mock persistent preview)
                    undoToastBanner

                    Spacer(minLength: 90)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }
        }
        .preferredColorScheme(.dark)
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

    // MARK: - Screen Title Row

    private var screenTitleRow: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("Classify Drives")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text("1 OF \(pendingCount) PENDING")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(Color(hex: "#00FF88"))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color(hex: "#00FF88").opacity(0.14))
                        .clipShape(Capsule())
                }

                Text("Review spatial telemetry & tax eligibility")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            Button {} label: {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .black))
                    Text("BATCH")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                }
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.07))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Main Swipe Deck Card

    private var mainSwipeDeckCard: some View {
        let tripMiles = currentTrip?.totalDistanceMiles ?? 12.8
        let tripDeduction = currentTrip?.taxDeductionValueUSD ?? (tripMiles * irsRate)
        let departure = currentTrip?.startAddress ?? "742 Evergreen Terr, Palo Alto"
        let arrival = currentTrip?.endAddress ?? "100 Financial Way, San Francisco"

        let durationMins: Int = {
            if let start = currentTrip?.startDate, let end = currentTrip?.endDate {
                return max(1, Int(end.timeIntervalSince(start) / 60))
            }
            return 34
        }()

        let avgSpeedMph: Double = currentTrip?.averageMovingSpeedMph ?? 22.6

        let timeString: String = {
            guard let start = currentTrip?.startDate, let end = currentTrip?.endDate else {
                return "Today • 11:24 AM – 11:58 AM"
            }
            let fmt = DateFormatter()
            fmt.dateFormat = "h:mm a"
            return "Today • \(fmt.string(from: start)) – \(fmt.string(from: end))"
        }()

        let vehicle = currentTrip?.vehicleName ?? BluetoothVehicleManager.shared.connectedVehicleName ?? "Prius 2024 (Auto)"
        let purpose = currentTrip?.businessPurpose ?? purposeTag

        return VStack(spacing: 12) {
            // Header Row: Time and Auto-Stopped Pill
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "#00FF88"))

                    Text(timeString)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }

                Spacer()

                Text("AUTO-STOPPED")
                    .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
            }

            // Stats Pill Row
            HStack(spacing: 8) {
                statPill(icon: "timer", text: "\(durationMins) MINS")
                statPill(icon: "point.topleft.down.to.point.bottomright.curvepath.fill", text: String(format: "%.1f MILES", tripMiles))
                statPill(icon: "gauge.with.needle", text: String(format: "%.1f MPH AVG", avgSpeedMph))
                Spacer()
            }

            // Spatial Route Arc Box
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(hex: "#080F17").opacity(0.95))

                // Curved Route Arc
                Canvas { context, size in
                    var path = Path()
                    path.move(to: CGPoint(x: 30, y: size.height * 0.75))
                    path.addCurve(
                        to: CGPoint(x: size.width - 40, y: size.height * 0.35),
                        control1: CGPoint(x: size.width * 0.35, y: size.height * 0.65),
                        control2: CGPoint(x: size.width * 0.65, y: size.height * 0.25)
                    )

                    // Glowing path line
                    context.stroke(
                        path,
                        with: .linearGradient(
                            Gradient(colors: [Color(hex: "#00E5FF"), Color(hex: "#00FF88")]),
                            startPoint: CGPoint(x: 30, y: size.height * 0.75),
                            endPoint: CGPoint(x: size.width - 40, y: size.height * 0.35)
                        ),
                        lineWidth: 3
                    )
                }
                .frame(height: 110)

                // Departure & Arrival Labels
                VStack(alignment: .leading, spacing: 32) {
                    // Departure
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(hex: "#00E5FF"))
                            .frame(width: 8, height: 8)
                            .shadow(color: Color(hex: "#00E5FF"), radius: 4)

                        VStack(alignment: .leading, spacing: 1) {
                            Text("DEPARTURE ORIGIN")
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                            Text(departure)
                                .font(.system(size: 11.5, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                    }
                    .padding(.leading, 12)

                    // Arrival
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(hex: "#00FF88"))
                            .frame(width: 8, height: 8)
                            .shadow(color: Color(hex: "#00FF88"), radius: 4)

                        VStack(alignment: .leading, spacing: 1) {
                            Text("ARRIVAL DESTINATION")
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                            Text(arrival)
                                .font(.system(size: 11.5, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                    }
                    .padding(.leading, 12)
                }
                .padding(.vertical, 8)
            }
            .frame(height: 110)

            // Potential IRS Write-Off Section
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("POTENTIAL IRS WRITE-OFF")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))

                    Spacer()

                    Text(String(format: "Standard %.0f¢/mi", irsRate * 100))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color(hex: "#00FF88"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "#00FF88").opacity(0.1))
                        .clipShape(Capsule())
                }

                HStack(alignment: .firstTextBaseline) {
                    Text(String(format: "+$%.2f", tripDeduction))
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(Color(hex: "#00FF88"))

                    Text("Accrued Yield")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))

                    Spacer()

                    Text("IRS Form 1040-ES")
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(12)
            .background(Color(hex: "#071616").opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color(hex: "#00FF88").opacity(0.12), lineWidth: 1))

            // Bottom Tags Row
            HStack(spacing: 8) {
                // Pill 1: Purpose
                HStack(spacing: 4) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 9))
                    Text(purpose)
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(Color(hex: "#00E5FF"))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.05))
                .clipShape(Capsule())

                // Pill 2: Vehicle
                HStack(spacing: 4) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 9))
                    Text(vehicle)
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(Color(hex: "#00FF88"))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.05))
                .clipShape(Capsule())

                // Pill 3: Split Drive
                HStack(spacing: 4) {
                    Image(systemName: "scissors")
                        .font(.system(size: 9))
                    Text("Split Drive")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.05))
                .clipShape(Capsule())

                Spacer()
            }
        }
        .padding(14)
        .background(Color(hex: "#0A1018").opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    swipeOffset.width > 40 ? Color(hex: "#00FF88") :
                    swipeOffset.width < -40 ? Color(hex: "#7B4FFF") :
                    Color.white.opacity(0.08),
                    lineWidth: 1.2
                )
        )
        .offset(swipeOffset)
        .opacity(swipeOpacity)
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    swipeOffset = gesture.translation
                }
                .onEnded { gesture in
                    if gesture.translation.width > 80 {
                        classifyActiveTrip(asBusiness: true)
                    } else if gesture.translation.width < -80 {
                        classifyActiveTrip(asBusiness: false)
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            swipeOffset = .zero
                        }
                    }
                }
        )
        .shadow(color: Color.black.opacity(0.4), radius: 16, x: 0, y: 8)
    }

    private func statPill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(Color(hex: "#00FF88"))
            Text(text)
                .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.05))
        .clipShape(Capsule())
    }

    // MARK: - Action Buttons

    private var classificationActionButtons: some View {
        let tripMiles = currentTrip?.totalDistanceMiles ?? 12.8
        let tripDeduction = currentTrip?.taxDeductionValueUSD ?? (tripMiles * irsRate)

        return HStack(spacing: 12) {
            // Left: Personal
            Button {
                classifyActiveTrip(asBusiness: false)
            } label: {
                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 11, weight: .black))
                        Text("PERSONAL")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(.white)

                    Text("$0.00 Deduction")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(hex: "#161824").opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color(hex: "#7B4FFF").opacity(0.3), lineWidth: 1)
                )
            }

            // Right: Business (Glowing Emerald Button)
            Button {
                classifyActiveTrip(asBusiness: true)
            } label: {
                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        Text("BUSINESS")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .black))
                    }
                    .foregroundStyle(Color(hex: "#061A13"))

                    Text(String(format: "+$%.2f WRITE-OFF", tripDeduction))
                        .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Color(hex: "#061A13").opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#00FF88"), Color(hex: "#00D670")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Color(hex: "#00FF88").opacity(0.35), radius: 8, x: 0, y: 3)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Undo Toast Banner

    private var undoToastBanner: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#00FF88").opacity(0.2))
                    .frame(width: 24, height: 24)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Color(hex: "#00FF88"))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(lastClassifiedTrip != nil
                     ? String(format: "Categorized %.1f mi as %@", lastClassifiedTrip!.miles, lastClassifiedTrip!.isBusiness ? "Business" : "Personal")
                     : "Categorized 6.4 mi as Business")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(.white)

                Text(lastClassifiedTrip != nil
                     ? String(format: "Accrued +$%.2f to Vault", lastClassifiedTrip!.deduction)
                     : "Accrued +$4.29 to Vault")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer()

            Button {
                undoLastClassification()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 9, weight: .bold))
                    Text(String(format: "Undo (%ds)", undoTimerCountdown))
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                }
                .foregroundStyle(Color(hex: "#00E5FF"))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color(hex: "#081F28"))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color(hex: "#00E5FF").opacity(0.3), lineWidth: 1))
            }
        }
        .padding(10)
        .background(Color(hex: "#0A1018").opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
    }

    // MARK: - Actions

    private func classifyActiveTrip(asBusiness: Bool) {
        let miles = currentTrip?.totalDistanceMiles ?? 12.8
        let deduction = asBusiness ? (currentTrip?.taxDeductionValueUSD ?? (miles * irsRate)) : 0.0

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            swipeOffset = asBusiness ? CGSize(width: 500, height: 0) : CGSize(width: -500, height: 0)
            swipeOpacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            if let trip = currentTrip {
                trip.tripClassification = asBusiness ? .business : .personal
                trip.needsReview = false
                CoreDataManager.shared.save()
            }
            lastClassifiedTrip = (miles: miles, isBusiness: asBusiness, deduction: deduction)
            undoTimerCountdown = 3
            showUndoBanner = true

            swipeOffset = .zero
            swipeOpacity = 1.0

            startUndoTimer()
        }
    }

    private func startUndoTimer() {
        undoTimerTask?.cancel()
        let task = DispatchWorkItem {
            if undoTimerCountdown > 1 {
                undoTimerCountdown -= 1
                startUndoTimer()
            } else {
                showUndoBanner = false
            }
        }
        undoTimerTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: task)
    }

    private func undoLastClassification() {
        undoTimerTask?.cancel()
        if let trip = allTrips.first {
            trip.needsReview = true
            trip.tripClassification = .unclassified
            CoreDataManager.shared.save()
        }
        withAnimation {
            showUndoBanner = false
            lastClassifiedTrip = nil
        }
    }
}
