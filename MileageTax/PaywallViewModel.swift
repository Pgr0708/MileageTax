//
//  PaywallViewModel.swift
//  MileageTax
//

import Foundation
import SwiftUI
import RevenueCat
internal import Combine

final class ProViewModel: BaseViewModel {
    @Published var selectedPackage: Package?
    @Published var allPackages = [Package]()

    func getOffering() {
        guard Purchases.isConfigured else {
            print("[RevenueCat] Purchases is not configured.")
            return
        }
        startLoading()
        Purchases.shared.getOfferings { [weak self] (offerings, error) in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.stopLoading()
                if let error = error {
                    print("[RevenueCat] Error getting offerings: \(error.localizedDescription)")
                }
                if let currentOffering = offerings?.current ?? offerings?.all.values.first {
                    self.allPackages = currentOffering.availablePackages
                    // Preselect annual plan, or the first available
                    self.selectedPackage = self.allPackages.first(where: { $0.packageType == .annual }) ?? self.allPackages.first
                }
            }
        }
    }

    func makePurchases(completion: @escaping () -> ()) {
        guard Purchases.isConfigured, let package = self.selectedPackage else { return }
        startLoading()
        Purchases.shared.purchase(package: package) { [weak self] (transaction, customerInfo, error, userCancelled) in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.checkUserIsPro(customerInfo: customerInfo)
                self.stopLoading()
                if self.isPro {
                    completion()
                }
            }
        }
    }

    func restorePurchases(completion: @escaping (Bool) -> ()) {
        guard Purchases.isConfigured else { 
            completion(false)
            return 
        }
        startLoading()
        Purchases.shared.restorePurchases { [weak self] (customerInfo, error) in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.checkUserIsPro(customerInfo: customerInfo)
                self.stopLoading()
                if self.isPro {
                    completion(true)
                } else {
                    completion(false)
                }
            }
        }
    }
}
