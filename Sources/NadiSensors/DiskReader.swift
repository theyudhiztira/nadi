import Foundation
import IOKit
import NadiCore

public final class DiskReader: DiskSensor, @unchecked Sendable {
    // Only touched from the Sampler actor. Refreshed every minute to pick up attached disks.
    private var drivers: [io_object_t] = []
    private var driversLoadedAt: Date?

    public init() {}

    deinit {
        drivers.forEach { IOObjectRelease($0) }
    }

    public func counters() -> ByteCounters? {
        refreshDriversIfStale()
        var read: UInt64 = 0
        var written: UInt64 = 0
        var found = false
        for entry in drivers {
            guard let stats = IORegistryEntryCreateCFProperty(entry, "Statistics" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? [String: Any]
            else { continue }
            read &+= (stats["Bytes (Read)"] as? NSNumber)?.uint64Value ?? 0
            written &+= (stats["Bytes (Write)"] as? NSNumber)?.uint64Value ?? 0
            found = true
        }
        return found ? ByteCounters(inBytes: read, outBytes: written) : nil
    }

    public func freeBytes() -> Int64? {
        let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage
    }

    private func refreshDriversIfStale() {
        if let driversLoadedAt, Date().timeIntervalSince(driversLoadedAt) < 60 { return }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOBlockStorageDriver"), &iterator) == KERN_SUCCESS
        else { return }
        defer { IOObjectRelease(iterator) }
        drivers.forEach { IOObjectRelease($0) }
        drivers = []
        while case let entry = IOIteratorNext(iterator), entry != 0 {
            drivers.append(entry)
        }
        driversLoadedAt = Date()
    }
}
