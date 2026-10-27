import Foundation

/// Reads the sensors and turns cumulative counters into rates.
///
/// With the panel closed, only the sensors behind the menu bar metrics are read every tick; the rest are read
/// every `backgroundInterval` to keep history for the panel charts, which average 5 s buckets anyway.
/// With the panel open (`setDetailed(true)`), everything is read every tick, plus per-process usage.
public actor Sampler {
    public static let intervalRange: ClosedRange<Double> = 0.5...5

    enum Group: CaseIterable {
        case cpu, memory, network, disk, power, cpuTemperature, gpuTemperature, fans, gpu, energy
    }

    private let sensors: SensorSet
    private let slowInterval: TimeInterval
    private let backgroundInterval: TimeInterval
    private var interval: TimeInterval
    private var fastGroups: Set<Group>
    private var detailed = false

    private var lastRead: [Group: Date] = [:]
    private var previousTicks: [CPUTicks]?
    private var previousNetwork: (counters: ByteCounters, date: Date)?
    private var previousDisk: (counters: ByteCounters, date: Date)?
    private var lastSlowRead: Date?
    private var diskFreeBytes: Int64?
    private var previousProcesses: (times: [Int32: UInt64], date: Date)?

    public init(
        sensors: SensorSet,
        menuBarMetrics: [MetricID] = MetricID.menuBarDefaults,
        interval: TimeInterval = 1,
        backgroundInterval: TimeInterval = 5,
        slowInterval: TimeInterval = 10
    ) {
        self.sensors = sensors
        self.interval = Self.clamp(interval)
        self.backgroundInterval = backgroundInterval
        self.slowInterval = slowInterval
        fastGroups = Self.groups(for: menuBarMetrics)
    }

    public func setInterval(_ seconds: TimeInterval) {
        interval = Self.clamp(seconds)
    }

    public func setMenuBarMetrics(_ metrics: [MetricID]) {
        fastGroups = Self.groups(for: metrics)
    }

    /// Reads every sensor each tick and adds per-process usage. Meant for while the panel is open.
    public func setDetailed(_ enabled: Bool) {
        detailed = enabled
        if !enabled { previousProcesses = nil }
    }

    public func sample(at now: Date = Date()) -> Snapshot {
        var snapshot = Snapshot(date: now)
        let due = Set(Group.allCases.filter { isDue($0, at: now) })
        for group in due { lastRead[group] = now }

        if due.contains(.cpu) {
            let ticks = sensors.cpu.ticks()
            if let ticks, let previousTicks {
                snapshot.cpu = CPULoad(from: previousTicks, to: ticks)
            }
            previousTicks = ticks
        }

        if due.contains(.memory) {
            snapshot.memory = sensors.memory.usage()
        }

        if due.contains(.network) {
            let counters = sensors.network.counters()
            if let counters, let previousNetwork {
                snapshot.network = ByteCounters.rates(from: previousNetwork.counters, to: counters,
                                                      seconds: now.timeIntervalSince(previousNetwork.date))
            }
            previousNetwork = counters.map { ($0, now) }
        }

        if due.contains(.disk) {
            let counters = sensors.disk.counters()
            if let counters, let previousDisk {
                snapshot.disk = ByteCounters.rates(from: previousDisk.counters, to: counters,
                                                   seconds: now.timeIntervalSince(previousDisk.date))
            }
            previousDisk = counters.map { ($0, now) }
        }

        if lastSlowRead.map({ now.timeIntervalSince($0) >= slowInterval }) ?? true {
            diskFreeBytes = sensors.disk.freeBytes()
            lastSlowRead = now
        }
        snapshot.diskFreeBytes = diskFreeBytes

        if due.contains(.power) { snapshot.power = sensors.power.status() }
        if due.contains(.cpuTemperature) { snapshot.cpuTemperature = sensors.temperature.cpuCelsius() }
        if due.contains(.gpuTemperature) { snapshot.gpuTemperature = sensors.temperature.gpuCelsius() }
        if due.contains(.fans) { snapshot.fanRPM = sensors.fans.rpm() }
        if due.contains(.gpu) { snapshot.gpuUsage = sensors.gpu.utilization() }
        if due.contains(.energy) { snapshot.energy = sensors.energy.reading() }

        if detailed, let processes = sensors.processes.samples() {
            if let previousProcesses {
                let usage = TopProcesses.usage(previous: previousProcesses.times, current: processes,
                                               seconds: now.timeIntervalSince(previousProcesses.date))
                // The panel shows five; keep a few more of each ranking so switching the toggle never comes up short.
                let keep = Set(TopProcesses.top(10, of: usage, by: .cpu).map(\.pid) + TopProcesses.top(10, of: usage, by: .memory).map(\.pid))
                snapshot.processes = usage.filter { keep.contains($0.pid) }
            }
            previousProcesses = (Dictionary(processes.map { ($0.pid, $0.cpuNanoseconds) }, uniquingKeysWith: { a, _ in a }), now)
        }

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

    private func isDue(_ group: Group, at now: Date) -> Bool {
        if detailed || fastGroups.contains(group) { return true }
        guard let last = lastRead[group] else { return true }
        // A little slack so a 1 s timer that fires a few ms early still lands on every fifth tick.
        return now.timeIntervalSince(last) >= backgroundInterval - interval / 2
    }

    private static func groups(for metrics: [MetricID]) -> Set<Group> {
        // CPU and memory are the cheapest reads and feed the panel's headline numbers; always keep them fresh.
        var groups: Set<Group> = [.cpu, .memory]
        for metric in metrics {
            switch metric {
            case .cpu: groups.insert(.cpu)
            case .memory: groups.insert(.memory)
            case .cpuTemperature: groups.insert(.cpuTemperature)
            case .gpuTemperature: groups.insert(.gpuTemperature)
            case .power: groups.insert(.power)
            case .gpu: groups.insert(.gpu)
            case .fan: groups.insert(.fans)
            case .cpuPower, .gpuPower: groups.insert(.energy)
            case .networkIn, .networkOut, .network: groups.insert(.network)
            case .diskRead, .diskWrite: groups.insert(.disk)
            }
        }
        return groups
    }

    private static func clamp(_ seconds: TimeInterval) -> TimeInterval {
        min(max(seconds, intervalRange.lowerBound), intervalRange.upperBound)
    }
}
