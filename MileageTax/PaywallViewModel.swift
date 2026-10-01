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
    /// Human-readable reason the paywall can't show plans (usually offline).
    @Published var loadErrorMessage: String = ""

    func getOffering() {
        guard Purchases.isConfigured else {
            loadErrorMessage = "Purchases are not configured."
            return
        }
        startLoading()
        Purchases.shared.getOfferings { [weak self] (offerings, error) in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.stopLoading()
                if let error = error {
                    print("[RevenueCat] Error getting offerings: \(error.localizedDescription)")
                    self.loadErrorMessage = "No internet connection. Connect to the internet and try again."
                } else {
                    self.loadErrorMessage = ""
                }
                if let currentOffering = offerings?.current ?? offerings?.all.values.first {
                    self.allPackages = currentOffering.availablePackages
                    // Preselect annual plan, or the first available
                    self.selectedPackage = self.allPackages.first(where: { $0.packageType == .annual }) ?? self.allPackages.first
                } else if self.allPackages.isEmpty, error == nil {
                    self.loadErrorMessage = "No subscription plans are available right now."
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
