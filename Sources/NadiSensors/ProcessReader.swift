import Darwin
import NadiCore

/// Every process's CPU time and memory footprint via `proc_pid_rusage`. Root processes answer EPERM and are skipped.
public final class ProcessReader: ProcessSensor {
    private let timebase: (numer: UInt64, denom: UInt64)

    public init() {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        timebase = (UInt64(info.numer), UInt64(max(info.denom, 1)))
    }

    public func samples() -> [ProcessSample]? {
        let capacity = Int(proc_listallpids(nil, 0)) + 64
        guard capacity > 64 else { return nil }
        var pids = [Int32](repeating: 0, count: capacity)
        let count = Int(proc_listallpids(&pids, Int32(capacity * MemoryLayout<Int32>.size)))
        guard count > 0 else { return nil }

        var nameBuffer = [CChar](repeating: 0, count: Int(MAXCOMLEN) * 2 + 1)
        return pids.prefix(count).compactMap { pid in
            guard pid > 0 else { return nil }
            var usage = rusage_info_v4()
            let result = withUnsafeMutablePointer(to: &usage) {
                $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V4, $0) }
            }
            guard result == 0 else { return nil }
            let length = proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
            let name = length > 0
                ? String(decoding: nameBuffer.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
                : "pid \(pid)"
            // rusage CPU times are Mach absolute units, not nanoseconds; on Apple Silicon one unit is 125/3 ns.
            let ticks = usage.ri_user_time &+ usage.ri_system_time
            let nanoseconds = ticks.multipliedFullWidth(by: timebase.numer)
            let (quotient, _) = timebase.denom.dividingFullWidth(nanoseconds)
            return ProcessSample(pid: pid, name: name, cpuNanoseconds: quotient, memoryBytes: usage.ri_phys_footprint)
        }
    }
}
