import Foundation
import IOKit
import NadiCore

/// GPU busy fraction from `IOAccelerator` → `PerformanceStatistics["Device Utilization %"]`.
public final class GPUReader: GPUSensor, @unchecked Sendable {
    private let service: io_service_t

    public init() {
        service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOAccelerator"))
    }

    deinit {
        if service != 0 { IOObjectRelease(service) }
    }

    public func utilization() -> Double? {
        guard service != 0,
              let stats = IORegistryEntryCreateCFProperty(service, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? [String: Any],
              let percent = (stats["Device Utilization %"] as? NSNumber)?.doubleValue
        else { return nil }
        return min(max(percent / 100, 0), 1)
    }
}
