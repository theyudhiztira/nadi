import Foundation
import IOKit
import NadiCore

public final class PowerReader: PowerSensor, @unchecked Sendable {
    // Fetching every AppleSmartBattery property copies large blobs (BatteryData, cell history) each tick;
    // reading only these keys costs a fraction.
    private static let keys = [
        "ExternalConnected", "IsCharging", "FullyCharged", "CurrentCapacity", "CycleCount", "AppleRawMaxCapacity",
        "DesignCapacity", "TimeRemaining", "Voltage", "InstantAmperage", "PowerTelemetryData", "AdapterDetails", "ChargerData",
    ]

    // Looked up once; matching a service by name every tick costs more than reading it.
    private let service: io_service_t

    public init() {
        service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
    }

    deinit {
        if service != 0 { IOObjectRelease(service) }
    }

    public func status() -> PowerStatus? {
        guard service != 0 else { return nil }
        var dict: [String: Any] = [:]
        for key in Self.keys {
            if let value = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() {
                dict[key] = value
            }
        }
        return PowerStatus(smartBattery: dict)
    }
}
