import CPrivate
import Foundation
import NadiCore

/// CPU temperature from SMC `Tp*` keys, falling back to the private IOHIDEventSystemClient (usage page 0xff00,
/// usage 5). On M1 Max / macOS 27 the HID `PMU tdie*` sensors stay near 58 °C at full load while `Tp*` tracks it.
/// GPU temperature from SMC `Tg*` keys, since HID names no GPU sensor there.
public final class TemperatureReader: TemperatureSensor, @unchecked Sendable {
    // Name prefixes of the CPU die sensors. M1 Max on macOS 27 reports `PMU tdie0` to `PMU tdie10`.
    private static let cpuPrefixes = ["PMU tdie", "pACC MTR Temp Sensor", "eACC MTR Temp Sensor"]
    private static let plausible = 1.0...150.0

    // Only touched from the Sampler actor, one call at a time.
    private let client: IOHIDEventSystemClient?
    private let cpuServices: [IOHIDServiceClient]
    private let smc: SMC?
    private let smcCPUKeys: [String]
    private let smcGPUKeys: [String]

    public init(smcKeys: [String]) {
        smc = SMC()
        smcCPUKeys = smcKeys.filter { $0.hasPrefix("Tp") }
        smcGPUKeys = smcKeys.filter { $0.hasPrefix("Tg") }

        guard let client = IOHIDEventSystemClientCreate(kCFAllocatorDefault) else {
            self.client = nil
            cpuServices = []
            return
        }
        IOHIDEventSystemClientSetMatching(client, ["PrimaryUsagePage": 0xff00, "PrimaryUsage": 5] as CFDictionary)
        let services = (IOHIDEventSystemClientCopyServices(client) as? [AnyObject] ?? [])
            .map { unsafeDowncast($0, to: IOHIDServiceClient.self) }
        self.client = client
        // Most sensors are listed twice under the same name; one of each is enough for a mean and halves the cost.
        var seen = Set<String>()
        cpuServices = services.filter { service in
            let name = IOHIDServiceClientCopyProperty(service, "Product" as CFString) as? String ?? ""
            return Self.cpuPrefixes.contains { name.hasPrefix($0) } && seen.insert(name).inserted
        }
    }

    public func cpuCelsius() -> Double? {
        smcMean(smcCPUKeys) ?? hidCPUCelsius()
    }

    private func hidCPUCelsius() -> Double? {
        let field = Int32(kIOHIDEventTypeTemperature << 16)
        let readings = cpuServices.compactMap { service -> Double? in
            guard let event = IOHIDServiceClientCopyEvent(service, Int64(kIOHIDEventTypeTemperature), 0, 0) else { return nil }
            return IOHIDEventGetFloatValue(event, field)
        }
        return Self.mean(readings)
    }

    public func gpuCelsius() -> Double? {
        smcMean(smcGPUKeys)
    }

    private func smcMean(_ keys: [String]) -> Double? {
        guard let smc else { return nil }
        return Self.mean(keys.compactMap { smc.readDouble($0) })
    }

    /// Idle sensors sometimes report 0 or garbage, so implausible readings are dropped.
    private static func mean(_ values: [Double]) -> Double? {
        let valid = values.filter { plausible.contains($0) }
        guard !valid.isEmpty else { return nil }
        return valid.reduce(0, +) / Double(valid.count)
    }
}
