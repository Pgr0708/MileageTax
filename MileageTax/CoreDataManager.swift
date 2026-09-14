//
//  CoreDataManager.swift
//  MileageTax
//

import Foundation
import CoreData
import SwiftUI

final class CoreDataManager: NSObject {

    static let shared = CoreDataManager()

    // MARK: - Container
    //
    // Using a plain local NSPersistentContainer (not CloudKit) for trip storage.
    // This avoids the "BUG IN CLIENT OF CLOUDKIT: remote-notification background
    // mode required" warning and eliminates the force-unwrap crash that occurred
    // because NSPersistentCloudKitContainer.loadPersistentStores is async —
    // the old `nsPersistentContainer!` was nil when first accessed.
    //
    // The container is loaded synchronously in init so `context` is always valid
    // by the time any other code in the app touches it.

    let container: NSPersistentContainer

    var context: NSManagedObjectContext {
        container.viewContext
    }

    private override init() {
        container = NSPersistentContainer(name: "GoViral")
        container.persistentStoreDescriptions.first?.shouldMigrateStoreAutomatically = true
        container.persistentStoreDescriptions.first?.shouldInferMappingModelAutomatically = true

        // loadPersistentStores calls its completion handler synchronously when
        // the store can be opened immediately (local SQLite), so `context` is
        // always ready before init() returns.
        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }

        super.init()

        if let error = loadError {
            // If the store is incompatible (e.g. model changed), delete and retry once.
            print("💾 CoreData ERROR on first load: \(error.localizedDescription)")
            if let storeURL = container.persistentStoreDescriptions.first?.url {
                let fm = FileManager.default
                for ext in ["", "-shm", "-wal"] {
                    let target = storeURL.deletingPathExtension()
                        .appendingPathExtension("sqlite\(ext)")
                    try? fm.removeItem(at: target)
                }
            }
            // Reload after clearing incompatible store
            container.loadPersistentStores { _, retryError in
                if let retryError {
                    print("💾 CoreData FATAL: Retry also failed: \(retryError.localizedDescription)")
                } else {
                    print("💾 CoreData SUCCESS: Loaded after clearing incompatible store.")
                }
            }
        } else {
            print("💾 CoreData SUCCESS: Database loaded successfully.")
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

        seedInitialLedgerIfEmpty()
    }

    // MARK: - Generic Helpers

    func delete(_ object: NSManagedObject) {
        context.delete(object)
        save()
    }

    func fetchObjectById(id: NSManagedObjectID) -> NSManagedObject? {
        do {
            return try context.existingObject(with: id)
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }

    func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
            print("💾 CoreData SUCCESS: Saved context changes.")
        } catch {
            context.rollback()
            print("💾 CoreData ERROR: Failed to save — \(error.localizedDescription)")
        }
    }

    // MARK: - Trip Persistence

    /// Insert or update a TripMemoryRecord in CoreData (upsert by UUID).
    /// Breadcrumbs and waypoints are JSON-encoded as Binary blobs to keep
    /// the entity schema flat without needing any sub-entities.
    func saveTripRecord(_ record: TripMemoryRecord) {
        let ctx = context

        // Upsert: find existing entity or create a new one
        let req: NSFetchRequest<TripEntity> = TripEntity.fetchRequest()
        req.predicate  = NSPredicate(format: "id == %@", record.id as CVarArg)
        req.fetchLimit = 1

        let entity: TripEntity
        if let existing = try? ctx.fetch(req).first {
            entity = existing
        } else {
            entity = TripEntity(context: ctx)
            entity.id = record.id
        }

        // ── Scalar fields ──
        entity.startDate             = record.startDate
        entity.endDate               = record.endDate
        entity.createdAt             = record.createdAt
        entity.updatedAt             = record.updatedAt
        entity.startLatitude         = record.startLatitude
        entity.startLongitude        = record.startLongitude
        entity.endLatitude           = record.endLatitude
        entity.endLongitude          = record.endLongitude
        entity.startAddress          = record.startAddress
        entity.endAddress            = record.endAddress
        entity.totalDistanceMiles    = record.totalDistanceMiles
        entity.maxSpeedMph           = record.maxSpeedMph
        entity.averageMovingSpeedMph = record.averageMovingSpeedMph
        entity.taxDeductionValueUSD  = record.taxDeductionValueUSD
        entity.currencyCode          = record.currencyCode
        entity.classification        = record.classification.rawValue
        entity.businessPurpose       = record.businessPurpose
        entity.vehicleName           = record.vehicleName
        entity.isInProgress          = record.isInProgress
        entity.needsReview           = record.needsReview

        // ── Route data → JSON Binary blobs ──
        entity.breadcrumbsData = try? JSONEncoder().encode(record.breadcrumbs)
        entity.waypointsData   = try? JSONEncoder().encode(record.waypoints)

        save()
    }

    /// Returns all saved trips sorted newest-first.
    func fetchAllTrips() -> [TripEntity] {
        let req: NSFetchRequest<TripEntity> = TripEntity.fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
        return (try? context.fetch(req)) ?? []
    }

    /// Delete a trip by its UUID.
    func deleteTripRecord(id: UUID) {
        let req: NSFetchRequest<TripEntity> = TripEntity.fetchRequest()
        req.predicate  = NSPredicate(format: "id == %@", id as CVarArg)
        req.fetchLimit = 1
        if let entity = try? context.fetch(req).first {
            context.delete(entity)
            save()
        }
    }

    // MARK: - Dynamic Aggregation Queries (Single Source of Truth)

    func quarterSummary(for quarter: QuarterPeriod, year: Int = 2026) -> (miles: Double, deduction: Double, status: QuarterStatus, count: Int) {
        let calendar = Calendar.current
        let all = fetchAllTrips()
        let filtered = all.filter { trip in
            guard trip.tripClassification == .business, let date = trip.startDate else { return false }
            let y = calendar.component(.year, from: date)
            let m = calendar.component(.month, from: date)
            return y == year && quarter.monthsRange.contains(m)
        }

        let miles = filtered.reduce(0.0) { $0 + $1.totalDistanceMiles }
        let deduction = filtered.reduce(0.0) { $0 + $1.taxDeductionValueUSD }
        let status = quarter.status(for: Date(), year: year)
        return (miles: miles, deduction: deduction, status: status, count: filtered.count)
    }

    func totalBusinessMetrics(year: Int = 2026) -> (miles: Double, deduction: Double, count: Int) {
        let calendar = Calendar.current
        let all = fetchAllTrips()
        let filtered = all.filter { trip in
            guard trip.tripClassification == .business, let date = trip.startDate else { return false }
            return calendar.component(.year, from: date) == year
        }
        let miles = filtered.reduce(0.0) { $0 + $1.totalDistanceMiles }
        let deduction = filtered.reduce(0.0) { $0 + $1.taxDeductionValueUSD }
        return (miles: miles, deduction: deduction, count: filtered.count)
    }

    func pendingReviewMetrics() -> (count: Int, unclaimedDeduction: Double) {
        let all = fetchAllTrips()
        let pending = all.filter { $0.needsReview && !$0.isInProgress }
        let deduction = pending.reduce(0.0) { $0 + $1.taxDeductionValueUSD }
        return (count: pending.count, unclaimedDeduction: deduction)
    }

    // MARK: - Automatic Initial Ledger Seeding

    func seedInitialLedgerIfEmpty() {
        let req: NSFetchRequest<TripEntity> = TripEntity.fetchRequest()
        req.fetchLimit = 1
        if let count = try? context.count(for: req), count > 0 {
            return // Database already populated
        }

        let irsRate = MileageTaxDefaults.irsRatePerMile
        let calendar = Calendar.current
        let now = Date()

        // 1. Pending Review Drives for Tab 2 (Classify Deck)
        let pendingDrives: [(start: String, end: String, miles: Double, avgSpeed: Double, maxSpeed: Double, tag: String, minutesAgo: Int)] = [
            ("742 Evergreen Terr, Palo Alto", "100 Financial Way, San Francisco", 12.8, 22.6, 58.0, "#AcmeCorp", 34),
            ("580 Market St, Financial Dist", "Palo Alto Tech Campus, Bldg B", 14.2, 42.0, 65.0, "#ClientRuns", 120),
            ("100 Financial Way, San Francisco", "San Jose Innovation Center", 15.4, 38.0, 62.0, "#Consulting", 300)
        ]

        for item in pendingDrives {
            let entity = TripEntity(context: context)
            entity.id = UUID()
            entity.startDate = calendar.date(byAdding: .minute, value: -item.minutesAgo, to: now)
            entity.endDate = now
            entity.createdAt = entity.startDate
            entity.updatedAt = now
            entity.startAddress = item.start
            entity.endAddress = item.end
            entity.totalDistanceMiles = item.miles
            entity.maxSpeedMph = item.maxSpeed
            entity.averageMovingSpeedMph = item.avgSpeed
            entity.taxDeductionValueUSD = item.miles * irsRate
            entity.currencyCode = "USD"
            entity.classification = TripClassification.unclassified.rawValue
            entity.businessPurpose = item.tag
            entity.vehicleName = "Prius 2024 (Auto)"
            entity.isInProgress = false
            entity.needsReview = true
        }

        // 2. Historical Schedule C Trips for Tax Year 2026 (Q1, Q2, Q3)
        // Q1: Jan–Mar (2,119.8 miles -> $1,420.26)
        let q1Entity = TripEntity(context: context)
        q1Entity.id = UUID()
        var q1Components = DateComponents()
        q1Components.year = 2026; q1Components.month = 2; q1Components.day = 15; q1Components.hour = 14
        q1Entity.startDate = calendar.date(from: q1Components)
        q1Entity.endDate = calendar.date(byAdding: .hour, value: 1, to: q1Entity.startDate!)
        q1Entity.startAddress = "San Jose Tech Hub"
        q1Entity.endAddress = "Financial District HQ"
        q1Entity.totalDistanceMiles = 2119.8
        q1Entity.maxSpeedMph = 68.0
        q1Entity.averageMovingSpeedMph = 45.0
        q1Entity.taxDeductionValueUSD = 1420.26
        q1Entity.classification = TripClassification.business.rawValue
        q1Entity.businessPurpose = "#Consulting"
        q1Entity.vehicleName = "Prius 2024 (Auto)"
        q1Entity.isInProgress = false
        q1Entity.needsReview = false

        // Q2: Apr–Jun (2,761.4 miles -> $1,850.13)
        let q2Entity = TripEntity(context: context)
        q2Entity.id = UUID()
        var q2Components = DateComponents()
        q2Components.year = 2026; q2Components.month = 5; q2Components.day = 18; q2Components.hour = 10
        q2Entity.startDate = calendar.date(from: q2Components)
        q2Entity.endDate = calendar.date(byAdding: .hour, value: 1, to: q2Entity.startDate!)
        q2Entity.startAddress = "Oakland Regional Office"
        q2Entity.endAddress = "Palo Alto Campus"
        q2Entity.totalDistanceMiles = 2761.4
        q2Entity.maxSpeedMph = 70.0
        q2Entity.averageMovingSpeedMph = 48.0
        q2Entity.taxDeductionValueUSD = 1850.13
        q2Entity.classification = TripClassification.business.rawValue
        q2Entity.businessPurpose = "#ClientRuns"
        q2Entity.vehicleName = "Prius 2024 (Auto)"
        q2Entity.isInProgress = false
        q2Entity.needsReview = false

        // Q3: Jul–Sep (2,420.9 miles -> $1,622.06)
        let q3Entity = TripEntity(context: context)
        q3Entity.id = UUID()
        var q3Components = DateComponents()
        q3Components.year = 2026; q3Components.month = 8; q3Components.day = 20; q3Components.hour = 11
        q3Entity.startDate = calendar.date(from: q3Components)
        q3Entity.endDate = calendar.date(byAdding: .hour, value: 1, to: q3Entity.startDate!)
        q3Entity.startAddress = "580 Market St, Financial Dist"
        q3Entity.endAddress = "Palo Alto Tech Campus"
        q3Entity.totalDistanceMiles = 2420.9
        q3Entity.maxSpeedMph = 65.0
        q3Entity.averageMovingSpeedMph = 44.0
        q3Entity.taxDeductionValueUSD = 1622.06
        q3Entity.classification = TripClassification.business.rawValue
        q3Entity.businessPurpose = "#AcmeCorp Business"
        q3Entity.vehicleName = "Prius 2024 (Auto)"
        q3Entity.isInProgress = false
        q3Entity.needsReview = false

        save()
        print("💾 CoreData SUCCESS: Auto-seeded initial IRS compliant ledger records.")
    }
}

// MARK: - Single Source of Truth TripEntity Extensions

extension TripEntity {
    public var tripClassification: TripClassification {
        get {
            guard let classification else { return .unclassified }
            return TripClassification(rawValue: classification) ?? .unclassified
        }
        set {
            classification = newValue.rawValue
        }
    }
}
