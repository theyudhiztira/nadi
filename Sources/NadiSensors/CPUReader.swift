import Darwin
import NadiCore

public final class CPUReader: CPUSensor {
    private let host = mach_host_self()

    public init() {}

    /// Performance and efficiency core counts, from `hw.perflevel0/1.logicalcpu`.
    public static var coreCounts: (performance: Int, efficiency: Int)? {
        guard let p = Sysctl.int("hw.perflevel0.logicalcpu") else { return nil }
        return (p, Sysctl.int("hw.perflevel1.logicalcpu") ?? 0)
    }

    public func ticks() -> [CPUTicks]? {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &cpuCount, &info, &infoCount) == KERN_SUCCESS,
              let info
        else { return nil }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info),
                          vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride))
        }
        let stride = Int(CPU_STATE_MAX)
        return (0..<Int(cpuCount)).map { core in
            func tick(_ state: Int32) -> UInt32 { UInt32(bitPattern: info[core * stride + Int(state)]) }
            return CPUTicks(user: tick(CPU_STATE_USER), system: tick(CPU_STATE_SYSTEM),
                            idle: tick(CPU_STATE_IDLE), nice: tick(CPU_STATE_NICE))
        }
    }
}
