import Foundation

/// Reads every sensor once per tick and turns cumulative counters into rates.
public actor Sampler {
    public static let intervalRange: ClosedRange<Double> = 0.5...5

    private let sensors: SensorSet
    private let slowInterval: TimeInterval
    private var interval: TimeInterval

    private var previousDate: Date?
    private var previousTicks: [CPUTicks]?
    private var previousNetwork: ByteCounters?
    private var previousDisk: ByteCounters?
    private var lastSlowRead: Date?
    private var diskFreeBytes: Int64?

    public init(sensors: SensorSet, interval: TimeInterval = 1, slowInterval: TimeInterval = 10) {
        self.sensors = sensors
        self.interval = Self.clamp(interval)
        self.slowInterval = slowInterval
    }

    public func setInterval(_ seconds: TimeInterval) {
        interval = Self.clamp(seconds)
    }

    public func sample(at now: Date = Date()) -> Snapshot {
        var snapshot = Snapshot(date: now)
        let elapsed = previousDate.map { now.timeIntervalSince($0) } ?? 0

        let ticks = sensors.cpu.ticks()
        if let ticks, let previousTicks {
            snapshot.cpu = CPULoad(from: previousTicks, to: ticks)
        }
        previousTicks = ticks

        snapshot.memory = sensors.memory.usage()

        let network = sensors.network.counters()
        if let network, let previousNetwork {
            snapshot.network = ByteCounters.rates(from: previousNetwork, to: network, seconds: elapsed)
        }
        previousNetwork = network

        let disk = sensors.disk.counters()
        if let disk, let previousDisk {
            snapshot.disk = ByteCounters.rates(from: previousDisk, to: disk, seconds: elapsed)
        }
        previousDisk = disk

        if lastSlowRead.map({ now.timeIntervalSince($0) >= slowInterval }) ?? true {
            diskFreeBytes = sensors.disk.freeBytes()
            lastSlowRead = now
        }
        snapshot.diskFreeBytes = diskFreeBytes

        snapshot.power = sensors.power.status()
        snapshot.cpuTemperature = sensors.temperature.cpuCelsius()
        snapshot.gpuTemperature = sensors.temperature.gpuCelsius()
        snapshot.fanRPM = sensors.fans.rpm()
        snapshot.gpuUsage = sensors.gpu.utilization()
        snapshot.energy = sensors.energy.reading()

        previousDate = now
        return snapshot
    }

    /// Samples until the calling task is cancelled.
    public func run(into store: LiveStore) async {
        while !Task.isCancelled {
            let snapshot = sample()
            await store.ingest(snapshot)
            try? await Task.sleep(for: .seconds(interval))
        }
    }

    private static func clamp(_ seconds: TimeInterval) -> TimeInterval {
        min(max(seconds, intervalRange.lowerBound), intervalRange.upperBound)
    }
}
