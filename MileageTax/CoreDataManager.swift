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
