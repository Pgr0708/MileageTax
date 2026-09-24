//
//  AutomationRuleManager.swift
//  MileageTax
//
//  Single Source of Truth for Automations & Classification Rules
//

import Foundation
import SwiftUI
internal import Combine

@MainActor
final class AutomationRuleManager: NSObject, ObservableObject {

    static let shared = AutomationRuleManager()

    @Published private(set) var customRules: [AutomationRule] = []

    private let defaultsKey = "MT_CustomAutomationRules_v1"

    private override init() {
        super.init()
        loadRules()
    }

    // MARK: - Actions

    func addRule(_ rule: AutomationRule) {
        customRules.append(rule)
        persistRules()
    }

    func toggleRule(id: UUID) {
        if let index = customRules.firstIndex(where: { $0.id == id }) {
            customRules[index].isEnabled.toggle()
            persistRules()
        }
    }

    func removeRule(id: UUID) {
        customRules.removeAll { $0.id == id }
        persistRules()
    }

    // MARK: - Persistence

    private func loadRules() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([AutomationRule].self, from: data) {
            self.customRules = decoded
        } else {
            self.customRules = []
        }
    }

    private func persistRules() {
        if let encoded = try? JSONEncoder().encode(customRules) {
            UserDefaults.standard.set(encoded, forKey: defaultsKey)
        }
    }
}
