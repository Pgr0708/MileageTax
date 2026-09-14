// BluetoothVehicleManager.swift — MileageTax
// Monitors CoreBluetooth for paired car Bluetooth names.
// When a known vehicle connects, it signals TripTrackerService to allow auto-tracking.
// Uses CBCentralManager in passive scan mode (no BLE services needed).

import Foundation
import CoreBluetooth
internal import Combine

@MainActor
final class BluetoothVehicleManager: NSObject, ObservableObject {

    static let shared = BluetoothVehicleManager()

    @Published private(set) var isConnectedToVehicle: Bool = false
    @Published private(set) var connectedVehicleName: String? = nil
    @Published private(set) var bluetoothState: CBManagerState = .unknown

    private var central: CBCentralManager!
    private var knownVehicleNames: Set<String> = []

    // UserDefaults key
    private let defaultsKey = "MTKnownVehicleBluetoothNames"

    private override init() {
        super.init()
        loadKnownVehicles()
        // queue: nil → runs on main; CBCentralManager will call delegate on main
        central = CBCentralManager(delegate: self, queue: nil, options: [
            CBCentralManagerOptionShowPowerAlertKey: false
        ])
    }

    // MARK: - Public API

    func addVehicle(name: String) {
        knownVehicleNames.insert(name.lowercased())
        saveKnownVehicles()
    }

    func removeVehicle(name: String) {
        knownVehicleNames.remove(name.lowercased())
        saveKnownVehicles()
        if connectedVehicleName?.lowercased() == name.lowercased() {
            isConnectedToVehicle = false
            connectedVehicleName = nil
        }
    }

    var knownVehicleList: [String] {
        Array(knownVehicleNames).sorted()
    }

    // MARK: - Persistence

    private func loadKnownVehicles() {
        let saved = UserDefaults.standard.stringArray(forKey: defaultsKey) ?? []
        knownVehicleNames = Set(saved.map { $0.lowercased() })
    }

    private func saveKnownVehicles() {
        UserDefaults.standard.set(Array(knownVehicleNames), forKey: defaultsKey)
    }

    // MARK: - Internal check

    private func checkConnectedPeripherals() {
        guard bluetoothState == .poweredOn else { return }
        // Retrieve already-connected peripherals for common car audio service UUIDs
        let carAudio = CBUUID(string: "0000111E-0000-1000-8000-00805F9B34FB") // Handsfree
        let a2dp     = CBUUID(string: "0000110B-0000-1000-8000-00805F9B34FB") // Audio sink

        let connected = central.retrieveConnectedPeripherals(withServices: [carAudio, a2dp])
        for peripheral in connected {
            let name = peripheral.name ?? ""
            if knownVehicleNames.contains(name.lowercased()) {
                isConnectedToVehicle = true
                connectedVehicleName = name
                return
            }
        }
        // No known vehicle found
        isConnectedToVehicle = false
        connectedVehicleName = nil
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothVehicleManager: CBCentralManagerDelegate {

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            self.bluetoothState = central.state
            self.checkConnectedPeripherals()
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didConnect peripheral: CBPeripheral) {
        Task { @MainActor in self.checkConnectedPeripherals() }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didDisconnectPeripheral peripheral: CBPeripheral,
                                    error: Error?) {
        Task { @MainActor in self.checkConnectedPeripherals() }
    }
}
