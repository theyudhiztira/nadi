import Foundation

public struct ByteRates: Sendable, Equatable {
    public var inPerSecond: Double
    public var outPerSecond: Double

    public init(inPerSecond: Double, outPerSecond: Double) {
        self.inPerSecond = inPerSecond
        self.outPerSecond = outPerSecond
    }
}

/// Everything sampled in one tick. A nil field means its reader failed or has nothing yet.
public struct Snapshot: Sendable, Equatable {
    public var date: Date
    public var cpu: CPULoad?
    public var memory: MemoryUsage?
    /// Network bytes per second, in = received.
    public var network: ByteRates?
    /// Disk bytes per second, in = read, out = written.
    public var disk: ByteRates?
    public var diskFreeBytes: Int64?
    public var power: PowerStatus?
    public var cpuTemperature: Double?

    public init(date: Date) {
        self.date = date
    }

    public func value(_ metric: MetricID) -> Double? {
        switch metric {
        case .cpu: cpu?.total
        case .memory: memory?.fraction
        case .cpuTemperature: cpuTemperature
        case .power: power?.menuBarWatts
        }
    }
}
