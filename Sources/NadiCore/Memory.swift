/// Page counts from `host_statistics64(HOST_VM_INFO64)`.
public struct VMPageCounts: Sendable, Equatable {
    public var internalPages: UInt64
    public var purgeablePages: UInt64
    public var wiredPages: UInt64
    public var compressedPages: UInt64
    public var pageSize: UInt64

    public init(internalPages: UInt64, purgeablePages: UInt64, wiredPages: UInt64, compressedPages: UInt64, pageSize: UInt64) {
        self.internalPages = internalPages
        self.purgeablePages = purgeablePages
        self.wiredPages = wiredPages
        self.compressedPages = compressedPages
        self.pageSize = pageSize
    }

    /// Activity Monitor's "Memory Used": app memory (internal minus purgeable) + wired + compressed.
    public var usedBytes: UInt64 {
        let app = internalPages > purgeablePages ? internalPages - purgeablePages : 0
        return (app + wiredPages + compressedPages) * pageSize
    }
}

public enum MemoryPressure: Int, Sendable {
    case normal = 1
    case warning = 2
    case critical = 4
}

public struct MemoryUsage: Sendable, Equatable {
    public var usedBytes: UInt64
    public var totalBytes: UInt64
    public var pressure: MemoryPressure?
    public var swapUsedBytes: UInt64?

    public init(usedBytes: UInt64, totalBytes: UInt64, pressure: MemoryPressure? = nil, swapUsedBytes: UInt64? = nil) {
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
        self.pressure = pressure
        self.swapUsedBytes = swapUsedBytes
    }

    public var fraction: Double {
        totalBytes == 0 ? 0 : min(1, Double(usedBytes) / Double(totalBytes))
    }
}
