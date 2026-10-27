public enum CounterDelta {
    /// Difference between two readings of a monotonic counter.
    /// A counter narrower than 64 bits that went backwards by less than half its range is treated as a wrap;
    /// anything else that went backwards is a reset and returns nil.
    public static func delta(from previous: UInt64, to current: UInt64, bitWidth: Int = 64) -> UInt64? {
        precondition((1...64).contains(bitWidth))
        if current >= previous { return current - previous }
        guard bitWidth < 64 else { return nil }
        let range = UInt64(1) << UInt64(bitWidth)
        guard previous < range, current < range else { return nil }
        let wrapped = range - previous + current
        return wrapped < range / 2 ? wrapped : nil
    }
}

public struct ByteCounters: Sendable, Equatable {
    public var inBytes: UInt64
    public var outBytes: UInt64

    public init(inBytes: UInt64, outBytes: UInt64) {
        self.inBytes = inBytes
        self.outBytes = outBytes
    }

    public static func rates(from previous: ByteCounters, to current: ByteCounters, seconds: Double) -> ByteRates? {
        guard seconds > 0,
              let inDelta = CounterDelta.delta(from: previous.inBytes, to: current.inBytes),
              let outDelta = CounterDelta.delta(from: previous.outBytes, to: current.outBytes)
        else { return nil }
        return ByteRates(inPerSecond: Double(inDelta) / seconds, outPerSecond: Double(outDelta) / seconds)
    }
}
