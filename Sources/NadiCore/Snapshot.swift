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
    public var gpuTemperature: Double?
    /// Busy fraction 0...1.
    public var gpuUsage: Double?
    /// Current speed of each fan.
    public var fanRPM: [Double]?
    public var energy: EnergyReading?
    /// Only sampled while the panel is open; nil otherwise.
    public var processes: [ProcessUsage]?

    public init(date: Date) {
        self.date = date
    }

    public func value(_ metric: MetricID) -> Double? {
        switch metric {
        case .cpu: cpu?.total
        case .memory: memory?.fraction
        case .cpuTemperature: cpuTemperature
        case .power: power?.menuBarWatts
        case .gpu: gpuUsage
        case .gpuTemperature: gpuTemperature
        case .fan: fanRPM?.max()
        case .cpuPower: energy?.cpuWatts
        case .gpuPower: energy?.gpuWatts
        case .networkIn: network?.inPerSecond
        case .networkOut: network?.outPerSecond
        case .diskRead: disk?.inPerSecond
        case .diskWrite: disk?.outPerSecond
        case .network: network.map { $0.inPerSecond + $0.outPerSecond }
        }
    }
}

/// What the menu bar's power slot shows (D21).
public enum PowerDisplay: Sendable, Equatable {
    /// Watts going into the battery. Slow when the adapter delivers under 40% of its rating.
    case charging(watts: Double, slow: Bool)
    /// Whole-system draw.
    case consuming(watts: Double?)

    /// Same threshold as the slow-charging alert in PLAN phase 7.
    public static let slowFraction = 0.4
}

extension Snapshot {
    public var powerDisplay: PowerDisplay {
        if let p = power, p.isCharging {
            var slow = false
            if let input = p.adapterInputWatts, let rating = p.adapterRatingWatts, rating > 0 {
                slow = input < rating * PowerDisplay.slowFraction
            }
            return .charging(watts: max(p.batteryWatts ?? 0, 0), slow: slow)
        }
        // The battery's own SystemLoad comes with the power reading the slot already needs; the SMC figure is a fallback.
        return .consuming(watts: power?.systemLoadWatts ?? energy?.systemWatts)
    }
}

public struct EnergyReading: Sendable, Equatable {
    public var cpuWatts: Double?
    public var gpuWatts: Double?
    /// Whole-system draw from the SMC, on AC or battery.
    public var systemWatts: Double?

    public init(cpuWatts: Double? = nil, gpuWatts: Double? = nil, systemWatts: Double? = nil) {
        self.cpuWatts = cpuWatts
        self.gpuWatts = gpuWatts
        self.systemWatts = systemWatts
    }
}
