//
//  ProfileStore.swift
//  MileageTax — profile name & photo (Single Source of Truth)
//
//  The name/photo are persisted to Core Data (CloudKit-backed), so they sync
//  across devices and restore after a reinstall. UserDefaults is kept as a
//  mirror for the @AppStorage-backed UI.
//

import Foundation
internal import Combine

@MainActor
final class ProfileStore: ObservableObject {

    static let shared = ProfileStore()

    @Published var name: String = ""
    @Published var photoData: Data?

    private init() {
        load()
    }

    func load() {
        if let profile = CoreDataManager.shared.fetchProfile() {
            name = profile.name ?? ""
            photoData = profile.photoData
        } else {
            name = UserDefaults.standard.string(forKey: AppStorageKeys.userName) ?? ""
            photoData = UserDefaults.standard.data(forKey: "MT_userPhotoData")
        }
    }

    func save(name newName: String, photo newPhoto: Data?) {
        name = newName
        photoData = newPhoto
        UserDefaults.standard.set(newName, forKey: AppStorageKeys.userName)
        if let data = newPhoto {
            UserDefaults.standard.set(data, forKey: "MT_userPhotoData")
        }
        CoreDataManager.shared.saveProfile(name: newName, photoData: newPhoto)
    }
}
