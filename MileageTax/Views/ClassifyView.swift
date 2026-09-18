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
    @State private var lastClassifiedTripID: NSManagedObjectID? = nil
    @State private var showBatchSheet: Bool = false
    @State private var undoTimerCountdown: Int = 3
    @State private var showUndoBanner: Bool = false
    @State private var undoTimerTask: DispatchWorkItem? = nil
    @State private var radarPulse: Bool = false

    private var currentCardTrip: TripEntity? {
        if let pid = preselectedTripID, let match = pendingTrips.first(where: { $0.id == pid }) {
            return match
        }
        return pendingTrips.first ?? allTrips.first
    }

    private var currentTrip: TripEntity? {
        currentCardTrip
    }

    private var pendingCount: Int {
        pendingTrips.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(hex: "#06090E").ignoresSafeArea()

                // Subtle ambient glow
                RadialGradient(
                    colors: [Color(hex: "#00E5FF").opacity(0.05), Color.clear],
                    center: .topLeading,
                    startRadius: 10,
                    endRadius: 400
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        if pendingCount > 0 {
                            // Screen Title Row (Classify Drives + 1 OF 3 PENDING + BATCH)
                            screenTitleRow

                            // Main Interactive Swipe Card
                            mainSwipeDeckCard

                            // Action Buttons (Personal vs Business)
                            classificationActionButtons
                        } else {
                            VStack(spacing: 16) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 64))
                                    .foregroundStyle(Color(hex: "#00FF88").opacity(0.8))
                                    .padding(.bottom, 8)
                                Text("All caught up!")
                                    .font(.system(size: 24, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("You have no pending drives to classify.")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 120)
                        }

                        // Undo Banner (shown after categorizing or mock persistent preview)
                        undoToastBanner

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, Device.topSafeArea + 58) // safe area + header height
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showBatchSheet) {
            BatchClassifySheet(pendingTrips: Array(pendingTrips), irsRate: irsRate)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                radarPulse = true
            }
        }
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

            Button { showBatchSheet = true } label: {
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
            cardHeaderRow(timeString: timeString)
            cardStatsRow(durationMins: durationMins, tripMiles: tripMiles, avgSpeedMph: avgSpeedMph)
            routeVisualizationBox(departure: departure, arrival: arrival)
            irsWriteOffBox(deduction: tripDeduction)
            cardMetadataTagsRow(purpose: purpose, vehicle: vehicle)
        }
        .padding(14)
        .background(Color(hex: "#0A1018").opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(cardBorderOverlay)
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

    @ViewBuilder
    private var cardBorderOverlay: some View {
        if swipeOffset.width > 40 {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color(hex: "#00FF88"), lineWidth: 1.5)
        } else if swipeOffset.width < -40 {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color(hex: "#7B4FFF"), lineWidth: 1.5)
        } else {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color(hex: "#00E5FF").opacity(0.35), Color(hex: "#00FF88").opacity(0.25), Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        }
    }

    private func cardHeaderRow(timeString: String) -> some View {
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
    }

    private func cardStatsRow(durationMins: Int, tripMiles: Double, avgSpeedMph: Double) -> some View {
        HStack(spacing: 8) {
            statPill(icon: "timer", text: "\(durationMins) MINS")
            statPill(icon: "point.topleft.down.to.point.bottomright.curvepath.fill", text: String(format: "%.1f MILES", tripMiles))
            statPill(icon: "gauge.with.needle", text: String(format: "%.1f MPH AVG", avgSpeedMph))
            Spacer()
        }
    }

    private func routeVisualizationBox(departure: String, arrival: String) -> some View {
        ZStack(alignment: .leading) {
            // Background artistic topography & particle route
            Image("classify_spatial_route_bg")
                .resizable()
                .scaledToFill()
                .frame(height: 128)
                .clipped()
                .overlay(
                    // Deep gradient protection on the left where text sits, fading toward the luminous right
                    LinearGradient(
                        colors: [
                            Color(hex: "#06090E").opacity(0.95),
                            Color(hex: "#06090E").opacity(0.85),
                            Color(hex: "#06090E").opacity(0.40),
                            Color(hex: "#06090E").opacity(0.65)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color(hex: "#00E5FF").opacity(0.4), Color(hex: "#00FF88").opacity(0.2), Color.white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )

            // Departure & Arrival Timeline and Text
            HStack(alignment: .top, spacing: 12) {
                // Vertical Timeline Route Line with Nodes
                VStack(spacing: 0) {
                    // Departure pulsing cyan node
                    ZStack {
                        Circle()
                            .stroke(Color(hex: "#00E5FF").opacity(radarPulse ? 0.0 : 0.8), lineWidth: 1.5)
                            .frame(width: radarPulse ? 20 : 10, height: radarPulse ? 20 : 10)
                        Circle()
                            .fill(Color(hex: "#00E5FF"))
                            .frame(width: 8, height: 8)
                            .shadow(color: Color(hex: "#00E5FF"), radius: 5)
                    }
                    .frame(width: 20, height: 20)

                    // Vertical glowing connector line
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#00E5FF").opacity(0.8), Color(hex: "#00FF88").opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 2, height: 28)
                        .padding(.vertical, 2)

                    // Arrival emerald pin
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#00FF88").opacity(0.2))
                            .frame(width: 20, height: 20)
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(hex: "#00FF88"))
                            .shadow(color: Color(hex: "#00FF88"), radius: 6)
                    }
                    .frame(width: 20, height: 20)
                }
                .padding(.top, 4)

                // Departure & Arrival Labels
                VStack(alignment: .leading, spacing: 14) {
                    // Departure Origin
                    VStack(alignment: .leading, spacing: 2) {
                        Text("DEPARTURE ORIGIN")
                            .font(.system(size: 8.5, weight: .black, design: .monospaced))
                            .foregroundStyle(Color(hex: "#00E5FF"))
                            .tracking(0.6)

                        Text(departure)
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .shadow(color: Color.black.opacity(0.9), radius: 4)
                    }

                    // Arrival Destination
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ARRIVAL DESTINATION")
                            .font(.system(size: 8.5, weight: .black, design: .monospaced))
                            .foregroundStyle(Color(hex: "#00FF88"))
                            .tracking(0.6)

                        Text(arrival)
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .shadow(color: Color.black.opacity(0.9), radius: 4)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .frame(height: 128)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
    }

    private func irsWriteOffBox(deduction: Double) -> some View {
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
                Text(String(format: "+$%.2f", deduction))
                    .font(.system(size: 29, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: "#00FF88"))
                    .shadow(color: Color(hex: "#00FF88").opacity(0.4), radius: 8, x: 0, y: 0)

                Text("Accrued Yield")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Color(hex: "#00FF88").opacity(0.7))
                    Text("IRS Form 1040-ES")
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
        }
        .padding(12)
        .background(Color(hex: "#071616").opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color(hex: "#00FF88").opacity(0.15), lineWidth: 1))
    }

    private func cardMetadataTagsRow(purpose: String, vehicle: String) -> some View {
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

            // Pill 3: Split Drive (coming soon — non-interactive)
            HStack(spacing: 4) {
                Image(systemName: "scissors")
                    .font(.system(size: 9))
                Text("Split Drive")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(.white.opacity(0.3))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.03))
            .clipShape(Capsule())
            .allowsHitTesting(false)

            Spacer()
        }
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
        let miles = currentTrip?.totalDistanceMiles ?? 0.0
        let deduction = asBusiness ? (currentTrip?.taxDeductionValueUSD ?? (miles * irsRate)) : 0.0
        let tripObjectID = currentTrip?.objectID

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
            lastClassifiedTripID = tripObjectID
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
        if let objectID = lastClassifiedTripID,
           let obj = CoreDataManager.shared.fetchObjectById(id: objectID) as? TripEntity {
            obj.needsReview = true
            obj.tripClassification = .unclassified
            CoreDataManager.shared.save()
        }
        withAnimation {
            showUndoBanner = false
            lastClassifiedTrip = nil
            lastClassifiedTripID = nil
        }
    }
}

// MARK: - Batch Classify Sheet

struct BatchClassifySheet: View {
    let pendingTrips: [TripEntity]
    let irsRate: Double
    @Environment(\.dismiss) private var dismiss

    private var totalMiles: Double { pendingTrips.reduce(0) { $0 + $1.totalDistanceMiles } }
    private var totalDeduction: Double { pendingTrips.reduce(0) { $0 + $1.taxDeductionValueUSD } }

    var body: some View {
        ZStack {
            Color(hex: "#06090E").ignoresSafeArea()

            VStack(spacing: 20) {
                // Handle
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)

                // Title
                VStack(spacing: 4) {
                    Text("Batch Classify")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("\(pendingTrips.count) pending drive\(pendingTrips.count == 1 ? "" : "s")  •  \(String(format: "%.1f", totalMiles)) mi total")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }

                // Summary card
                VStack(spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("MAX POTENTIAL YIELD")
                                .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.45))
                            Text(String(format: "+$%.2f", totalDeduction))
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundStyle(Color(hex: "#00FF88"))
                        }
                        Spacer()
                        Image(systemName: "banknote.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(Color(hex: "#00FF88").opacity(0.3))
                    }
                    .padding(14)
                    .background(Color(hex: "#0A1A12").opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(hex: "#00FF88").opacity(0.25), lineWidth: 1))
                }

                Spacer()

                // Action buttons
                VStack(spacing: 10) {
                    // Mark All Business
                    Button {
                        for trip in pendingTrips {
                            trip.tripClassification = .business
                            trip.needsReview = false
                        }
                        CoreDataManager.shared.save()
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "briefcase.fill")
                                .font(.system(size: 14, weight: .black))
                            Text("Mark All as Business")
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                            Spacer()
                            Text(String(format: "+$%.2f", totalDeduction))
                                .font(.system(size: 13, weight: .black, design: .monospaced))
                        }
                        .foregroundStyle(Color(hex: "#061A13"))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(LinearGradient(colors: [Color(hex: "#00FF88"), Color(hex: "#00D670")], startPoint: .leading, endPoint: .trailing))
                        .clipShape(Capsule())
                        .shadow(color: Color(hex: "#00FF88").opacity(0.35), radius: 10, y: 4)
                    }

                    // Mark All Personal
                    Button {
                        for trip in pendingTrips {
                            trip.tripClassification = .personal
                            trip.needsReview = false
                        }
                        CoreDataManager.shared.save()
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "house.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text("Mark All as Personal")
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                            Spacer()
                            Text("$0.00")
                                .font(.system(size: 13, weight: .black, design: .monospaced))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color(hex: "#161824").opacity(0.9))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Color(hex: "#7B4FFF").opacity(0.4), lineWidth: 1))
                    }

                    // Cancel
                    Button { dismiss() } label: {
                        Text("Cancel")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                }
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 20)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
    }
}
