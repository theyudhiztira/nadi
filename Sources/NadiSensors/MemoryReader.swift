import Darwin
import NadiCore

public final class MemoryReader: MemorySensor {
    private let host = mach_host_self()
    private let pageSize = UInt64(Sysctl.int("hw.pagesize") ?? 16384)
    private let totalBytes = UInt64(Sysctl.int("hw.memsize") ?? 0)

    public init() {}

    public func usage() -> MemoryUsage? {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let kr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS, totalBytes > 0 else { return nil }
        let pages = VMPageCounts(
            internalPages: UInt64(stats.internal_page_count),
            purgeablePages: UInt64(stats.purgeable_count),
            wiredPages: UInt64(stats.wire_count),
            compressedPages: UInt64(stats.compressor_page_count),
            pageSize: pageSize
        )
        let swap = Sysctl.value("vm.swapusage", as: xsw_usage.self, initial: xsw_usage())
        return MemoryUsage(
            usedBytes: pages.usedBytes,
            totalBytes: totalBytes,
            pressure: Sysctl.int("kern.memorystatus_vm_pressure_level").flatMap(MemoryPressure.init(rawValue:)),
            swapUsedBytes: swap.map { UInt64($0.xsu_used) }
        )
    }
}
