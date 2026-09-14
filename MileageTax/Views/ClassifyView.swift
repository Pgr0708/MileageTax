// ClassifyView.swift — MileageTax · Tab 2: Classify (Swipe Deck)
// Card-swipe interface: right = Business, left = Personal, down = Skip.
// Also hosts the full filterable trip history list.

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

    @State private var filter: ClassifyFilter = .pending
    @State private var swipeOffset: CGSize = .zero
    @State private var swipeOpacity: Double = 1
    @State private var purposeText: String = ""
    @State private var showPurposeInput = false

    enum ClassifyFilter: String, CaseIterable {
        case pending = "Pending"
        case business = "Business"
        case personal = "Personal"
        case all = "All"
    }

    private var displayedTrips: [TripEntity] {
        switch filter {
        case .pending:  return pendingTrips.map { $0 }
        case .business: return allTrips.filter { $0.classification == "business" }
        case .personal: return allTrips.filter { $0.classification == "personal" }
        case .all:      return allTrips.map { $0 }
        }
    }

    private var topTrip: TripEntity? { pendingTrips.first }

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                headerSection
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.sm)

                if filter == .pending && !pendingTrips.isEmpty {
                    swipeDeck
                        .padding(.top, AppSpacing.md)
                } else {
                    tripList
                }

                Spacer(minLength: 100)
            }
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            Color.obsidian.ignoresSafeArea()
            RadialGradient(
                colors: [Color.deepPurple.opacity(0.07), .clear],
                center: .topTrailing, startRadius: 0, endRadius: 300)
            .ignoresSafeArea()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Classify")
                        .font(.displayMedium)
                        .foregroundStyle(Color.textPrimary)
                    Text("\(pendingTrips.count) trips pending")
                        .font(.captionText)
                        .foregroundStyle(pendingTrips.count > 0 ? Color.amberGlow : Color.textTertiary)
                }
                Spacer()
                // Filter chips
                Menu {
                    ForEach(ClassifyFilter.allCases, id: \.self) { f in
                        Button(f.rawValue) { filter = f }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(filter.rawValue)
                            .font(.captionText)
                        Image(systemName: "chevron.down")
                            .font(.micro)
                    }
                    .foregroundStyle(Color.neonEmerald)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.neonEmerald.opacity(0.12))
                            .overlay(Capsule().strokeBorder(Color.neonEmerald.opacity(0.3), lineWidth: 1)))
                }
            }

            // Swipe hint
            if filter == .pending && !pendingTrips.isEmpty {
                HStack(spacing: AppSpacing.xl) {
                    Label("Personal", systemImage: "arrow.left")
                        .font(.captionText).foregroundStyle(Color.deepPurple)
                    Spacer()
                    Label("Business", systemImage: "arrow.right")
                        .font(.captionText).foregroundStyle(Color.neonEmerald)
                }
            }
        }
    }

    // MARK: - Swipe Deck

    private var swipeDeck: some View {
        ZStack {
            // Stack background cards
            ForEach(Array(pendingTrips.prefix(3).reversed().enumerated()), id: \.offset) { idx, trip in
                if idx > 0 {
                    classifyCard(trip: trip, isTop: false)
                        .scaleEffect(1 - CGFloat(idx) * 0.04)
                        .offset(y: CGFloat(idx) * 10)
                        .opacity(1 - Double(idx) * 0.25)
                }
            }
            // Top card
            if let top = topTrip {
                classifyCard(trip: top, isTop: true)
                    .offset(swipeOffset)
                    .rotationEffect(.degrees(swipeOffset.width / 25))
                    .opacity(swipeOpacity)
                    .gesture(
                        DragGesture()
                            .onChanged { v in
                                swipeOffset = v.translation
                            }
                            .onEnded { v in
                                handleSwipe(trip: top, velocity: v)
                            }
                    )
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: swipeOffset)
    }

    private func classifyCard(trip: TripEntity, isTop: Bool) -> some View {
        VStack(spacing: AppSpacing.lg) {
            // Route
            VStack(spacing: AppSpacing.sm) {
                routeRow(icon: "mappin.circle.fill", color: .neonEmerald,
                         address: trip.startAddress ?? "Unknown")
                Rectangle()
                    .fill(Color.glassBorder)
                    .frame(width: 2, height: 30)
                routeRow(icon: "mappin.and.ellipse", color: .electricCyan,
                         address: trip.endAddress ?? "Unknown")
            }
            .padding(.top, AppSpacing.md)

            Divider().background(Color.glassBorder)

            // Stats
            HStack {
                metricBadge(icon: "ruler", value: String(format: "%.1f mi", trip.totalDistanceMiles), color: .neonEmerald)
                Spacer()
                metricBadge(icon: "dollarsign", value: String(format: "$%.2f", trip.taxDeductionValueUSD), color: .amberGlow)
                Spacer()
                metricBadge(icon: "gauge.high", value: String(format: "%.0f mph", trip.maxSpeedMph), color: .electricCyan)
            }

            // Purpose input (only top card)
            if isTop {
                purposeSection(trip: trip)
            }

            // Action buttons (only top card)
            if isTop {
                actionButtons(trip: trip)
            }
        }
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#111823"), Color(hex: "#0A0F18")],
                        startPoint: .top, endPoint: .bottom))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                        .strokeBorder(isTop ? swipeBorderColor : Color.glassBorder, lineWidth: 1.5)))
        .shadow(color: Color.black.opacity(0.5), radius: 24, y: 12)
        .overlay(swipeLabel, alignment: swipeLabelAlignment)
    }

    private func routeRow(icon: String, color: Color, address: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon).font(.body).foregroundStyle(color)
            Text(address)
                .font(.subheadline)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricBadge(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.captionText).foregroundStyle(color)
            Text(value).font(.captionText).foregroundStyle(Color.textPrimary)
        }
    }

    private func purposeSection(trip: TripEntity) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "text.badge.plus")
                .foregroundStyle(Color.textSecondary)
            TextField("Add purpose (optional)…", text: $purposeText)
                .font(.bodyText)
                .foregroundStyle(Color.textPrimary)
                .tint(Color.neonEmerald)
        }
        .padding(AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                        .strokeBorder(Color.glassBorder, lineWidth: 1)))
    }

    private func actionButtons(trip: TripEntity) -> some View {
        HStack(spacing: AppSpacing.md) {
            // Personal
            Button {
                classify(trip: trip, as: "personal")
            } label: {
                Label("Personal", systemImage: "house.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppGradient.purpleGradient)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            }
            // Business
            Button {
                classify(trip: trip, as: "business")
            } label: {
                Label("Business", systemImage: "briefcase.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppGradient.emeraldPulse)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                    .emeraldGlow()
            }
        }
    }

    // MARK: - Swipe Indicator

    private var swipeBorderColor: Color {
        if swipeOffset.width > 40  { return Color.neonEmerald }
        if swipeOffset.width < -40 { return Color.deepPurple }
        return Color.glassBorder
    }

    private var swipeLabel: some View {
        Group {
            if swipeOffset.width > 40 {
                Text("BUSINESS")
                    .font(.headline).foregroundStyle(Color.neonEmerald)
                    .padding(8)
                    .background(Color.neonEmerald.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .opacity(min(1, Double(swipeOffset.width - 40) / 60))
                    .padding()
            } else if swipeOffset.width < -40 {
                Text("PERSONAL")
                    .font(.headline).foregroundStyle(Color.deepPurple)
                    .padding(8)
                    .background(Color.deepPurple.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .opacity(min(1, Double(-swipeOffset.width - 40) / 60))
                    .padding()
            }
        }
    }

    private var swipeLabelAlignment: Alignment {
        swipeOffset.width > 0 ? .topLeading : .topTrailing
    }

    // MARK: - Trip List (non-pending)

    private var tripList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: AppSpacing.sm) {
                if displayedTrips.isEmpty {
                    Text("No trips in this category")
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                        .padding(.top, AppSpacing.xxl)
                } else {
                    ForEach(displayedTrips, id: \.objectID) { trip in
                        TripRowCard(trip: trip)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
        }
    }

    // MARK: - Actions

    private func classify(trip: TripEntity, as classification: String) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            swipeOffset = classification == "business"
                ? CGSize(width: 500, height: 0)
                : CGSize(width: -500, height: 0)
            swipeOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            trip.classification = classification
            trip.needsReview    = false
            if !purposeText.isEmpty { trip.businessPurpose = purposeText }
            CoreDataManager.shared.save()
            purposeText  = ""
            swipeOffset  = .zero
            swipeOpacity = 1
        }
    }

    private func handleSwipe(trip: TripEntity, velocity: DragGesture.Value) {
        let w = velocity.translation.width
        if w > 80       { classify(trip: trip, as: "business") }
        else if w < -80 { classify(trip: trip, as: "personal") }
        else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                swipeOffset = .zero
            }
        }
    }
}
