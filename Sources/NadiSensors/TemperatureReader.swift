import CPrivate
import Foundation
import NadiCore

/// SoC temperatures from the private IOHIDEventSystemClient (usage page 0xff00, usage 5).
public final class HIDTemperatureReader: TemperatureSensor, @unchecked Sendable {
    // Name prefixes of the CPU die sensors. M1 Max on macOS 27 reports `PMU tdie0` to `PMU tdie10`.
    private static let cpuPrefixes = ["PMU tdie", "pACC MTR Temp Sensor", "eACC MTR Temp Sensor"]

    // Only touched from the Sampler actor, one call at a time.
    private let client: IOHIDEventSystemClient?
    private let cpuServices: [IOHIDServiceClient]

    public init() {
        guard let client = IOHIDEventSystemClientCreate(kCFAllocatorDefault) else {
            self.client = nil
            cpuServices = []
            return
        }
        IOHIDEventSystemClientSetMatching(client, ["PrimaryUsagePage": 0xff00, "PrimaryUsage": 5] as CFDictionary)
        let services = (IOHIDEventSystemClientCopyServices(client) as? [AnyObject] ?? [])
            .map { unsafeDowncast($0, to: IOHIDServiceClient.self) }
        self.client = client
        cpuServices = services.filter { service in
            let name = IOHIDServiceClientCopyProperty(service, "Product" as CFString) as? String ?? ""
            return Self.cpuPrefixes.contains { name.hasPrefix($0) }
        }
    }

    public func cpuCelsius() -> Double? {
        let field = Int32(kIOHIDEventTypeTemperature << 16)
        let readings = cpuServices.compactMap { service -> Double? in
            guard let event = IOHIDServiceClientCopyEvent(service, Int64(kIOHIDEventTypeTemperature), 0, 0) else { return nil }
            let celsius = IOHIDEventGetFloatValue(event, field)
            // Idle sensors sometimes report 0 or garbage.
            return (1...150).contains(celsius) ? celsius : nil
        }
        guard !readings.isEmpty else { return nil }
        return readings.reduce(0, +) / Double(readings.count)
    }
}
