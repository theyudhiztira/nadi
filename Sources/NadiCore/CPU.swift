/// Cumulative per-core tick counters from `host_processor_info`. The kernel keeps them as 32-bit values.
public struct CPUTicks: Sendable, Equatable {
    public var user: UInt32
    public var system: UInt32
    public var idle: UInt32
    public var nice: UInt32

    public init(user: UInt32, system: UInt32, idle: UInt32, nice: UInt32) {
        self.user = user
        self.system = system
        self.idle = idle
        self.nice = nice
    }
}

public struct CPULoad: Sendable, Equatable {
    /// Busy fraction 0...1 across all cores.
    public var total: Double
    public var perCore: [Double]

    public init(total: Double, perCore: [Double]) {
        self.total = total
        self.perCore = perCore
    }

    /// Nil when the core count changed or a counter reset between the two readings.
    public init?(from previous: [CPUTicks], to current: [CPUTicks]) {
        guard !current.isEmpty, previous.count == current.count else { return nil }
        var busySum: UInt64 = 0
        var allSum: UInt64 = 0
        var perCore: [Double] = []
        perCore.reserveCapacity(current.count)
        for (old, new) in zip(previous, current) {
            func d(_ a: UInt32, _ b: UInt32) -> UInt64? {
                CounterDelta.delta(from: UInt64(a), to: UInt64(b), bitWidth: 32)
            }
            guard let user = d(old.user, new.user),
                  let system = d(old.system, new.system),
                  let idle = d(old.idle, new.idle),
                  let nice = d(old.nice, new.nice)
            else { return nil }
            let busy = user + system + nice
            let all = busy + idle
            perCore.append(all == 0 ? 0 : Double(busy) / Double(all))
            busySum += busy
            allSum += all
        }
        self.total = allSum == 0 ? 0 : Double(busySum) / Double(allSum)
        self.perCore = perCore
    }
}
