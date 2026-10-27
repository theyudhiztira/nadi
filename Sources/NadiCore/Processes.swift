/// One process's cumulative counters, as read from `proc_pid_rusage`.
public struct ProcessSample: Sendable, Equatable {
    public var pid: Int32
    public var name: String
    /// User + system CPU time in nanoseconds.
    public var cpuNanoseconds: UInt64
    public var memoryBytes: UInt64

    public init(pid: Int32, name: String, cpuNanoseconds: UInt64, memoryBytes: UInt64) {
        self.pid = pid
        self.name = name
        self.cpuNanoseconds = cpuNanoseconds
        self.memoryBytes = memoryBytes
    }
}

public struct ProcessUsage: Sendable, Equatable, Identifiable {
    public var pid: Int32
    public var name: String
    /// Share of one core, like Activity Monitor: a process using two full cores is 2.0.
    public var cpu: Double
    public var memoryBytes: UInt64

    public var id: Int32 { pid }

    public init(pid: Int32, name: String, cpu: Double, memoryBytes: UInt64) {
        self.pid = pid
        self.name = name
        self.cpu = cpu
        self.memoryBytes = memoryBytes
    }
}

public enum ProcessRanking: String, Sendable, CaseIterable {
    case cpu
    case memory
}

public enum TopProcesses {
    /// CPU share since the previous reading. A pid seen for the first time gets no CPU figure yet and is skipped.
    public static func usage(previous: [Int32: UInt64], current: [ProcessSample], seconds: Double) -> [ProcessUsage] {
        guard seconds > 0 else { return [] }
        return current.compactMap { sample in
            guard let before = previous[sample.pid],
                  let delta = CounterDelta.delta(from: before, to: sample.cpuNanoseconds)
            else { return nil }
            return ProcessUsage(pid: sample.pid, name: sample.name, cpu: Double(delta) / 1e9 / seconds, memoryBytes: sample.memoryBytes)
        }
    }

    public static func top(_ count: Int, of usages: [ProcessUsage], by ranking: ProcessRanking) -> [ProcessUsage] {
        let sorted = switch ranking {
        case .cpu: usages.sorted { ($0.cpu, $0.memoryBytes) > ($1.cpu, $1.memoryBytes) }
        case .memory: usages.sorted { ($0.memoryBytes, $0.cpu) > ($1.memoryBytes, $1.cpu) }
        }
        return Array(sorted.prefix(count))
    }
}
