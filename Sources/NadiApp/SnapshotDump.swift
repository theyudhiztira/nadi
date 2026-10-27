import Foundation
import NadiCore
import NadiSensors

/// Prints readings for checking against Activity Monitor and `pmset -g batt` by hand.
enum SnapshotDump {
    static func run(count: Int) async {
        let sampler = Sampler(sensors: .system())
        for i in 0...count {
            let s = await sampler.sample()
            // The first sample only primes the counters.
            if i > 0 { print(describe(s)) }
            if i < count { try? await Task.sleep(for: .seconds(1)) }
        }
    }

    static func describe(_ s: Snapshot) -> String {
        let f = MetricFormatter.self
        var parts = [
            "cpu \(f.format(s.cpu?.total, for: .cpu))",
            "ram \(s.memory.map { "\(f.bytes(Double($0.usedBytes), binary: true)) / \(f.bytes(Double($0.totalBytes), binary: true)) (\(f.format($0.fraction, for: .memory)))" } ?? f.missing)",
            "pressure \(s.memory?.pressure.map { "\($0)" } ?? f.missing)",
            "swap \(s.memory?.swapUsedBytes.map { f.bytes(Double($0), binary: true) } ?? f.missing)",
            "net down \(s.network.map { f.bytesPerSecond($0.inPerSecond) } ?? f.missing) up \(s.network.map { f.bytesPerSecond($0.outPerSecond) } ?? f.missing)",
            "disk r \(s.disk.map { f.bytesPerSecond($0.inPerSecond) } ?? f.missing) w \(s.disk.map { f.bytesPerSecond($0.outPerSecond) } ?? f.missing)",
            "free \(s.diskFreeBytes.map { f.bytes(Double($0)) } ?? f.missing)",
            "temp \(f.format(s.cpuTemperature, for: .cpuTemperature)) gpu \(f.format(s.gpuTemperature, for: .gpuTemperature))",
            "fans \(s.fanRPM.map { $0.map { "\(Int($0))" }.joined(separator: "/") } ?? f.missing) rpm",
            "gpu \(f.format(s.gpuUsage, for: .gpu))",
            "watts cpu \(f.format(s.energy?.cpuWatts, for: .cpuPower)) gpu \(f.format(s.energy?.gpuWatts, for: .gpuPower)) system \(f.format(s.energy?.systemWatts, for: .power))",
        ]
        if let p = s.power {
            parts.append("power \(f.format(p.menuBarWatts, for: .power)) ac=\(p.externalConnected) charging=\(p.isCharging) \(p.percent.map { "\($0)%" } ?? f.missing) rating \(p.adapterRatingWatts.map(f.watts) ?? f.missing) battery \(p.batteryWatts.map { String(format: "%.1fW", $0) } ?? f.missing)")
        }
        return parts.joined(separator: " | ")
    }
}
