import Foundation
import IOKit
import NadiCore

public final class PowerReader: PowerSensor {
    public init() {}

    public func status() -> PowerStatus? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = properties?.takeRetainedValue() as? [String: Any]
        else { return nil }
        return PowerStatus(smartBattery: dict)
    }
}
