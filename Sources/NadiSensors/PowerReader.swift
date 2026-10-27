import Foundation
import IOKit
import NadiCore

public final class PowerReader: PowerSensor, @unchecked Sendable {
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
        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = properties?.takeRetainedValue() as? [String: Any]
        else { return nil }
        return PowerStatus(smartBattery: dict)
    }
}
