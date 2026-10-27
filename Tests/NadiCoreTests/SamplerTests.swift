import Foundation
import Testing
@testable import NadiCore

private final class Fakes: CPUSensor, MemorySensor, NetworkSensor, DiskSensor, PowerSensor, TemperatureSensor, @unchecked Sendable {
    var queuedTicks: [[CPUTicks]] = []
    var network: [ByteCounters] = []
    var freeCalls = 0

    func ticks() -> [CPUTicks]? { queuedTicks.isEmpty ? nil : queuedTicks.removeFirst() }
    func usage() -> MemoryUsage? { MemoryUsage(usedBytes: 1, totalBytes: 4) }
    func counters() -> ByteCounters? { network.isEmpty ? nil : network.removeFirst() }
    func freeBytes() -> Int64? { freeCalls += 1; return 42 }
    func status() -> PowerStatus? { nil }
    func cpuCelsius() -> Double? { 55 }
}

struct SamplerTests {
    @Test func firstSampleHasNoRatesThenComputesThem() async {
        let fakes = Fakes()
        fakes.queuedTicks = [
            [CPUTicks(user: 0, system: 0, idle: 0, nice: 0)],
            [CPUTicks(user: 25, system: 0, idle: 75, nice: 0)],
        ]
        // Network and disk share `counters()` in this fake, so each tick consumes two entries.
        fakes.network = [
            .init(inBytes: 0, outBytes: 0), .init(inBytes: 0, outBytes: 0),
            .init(inBytes: 2_000, outBytes: 0), .init(inBytes: 0, outBytes: 0),
        ]
        let sampler = Sampler(sensors: SensorSet(cpu: fakes, memory: fakes, network: fakes, disk: fakes, power: fakes, temperature: fakes))
        let start = Date(timeIntervalSince1970: 0)

        let first = await sampler.sample(at: start)
        #expect(first.cpu == nil)
        #expect(first.network == nil)
        #expect(first.memory?.fraction == 0.25)
        #expect(first.cpuTemperature == 55)

        let second = await sampler.sample(at: start.addingTimeInterval(2))
        #expect(second.cpu?.total == 0.25)
        #expect(second.network == ByteRates(inPerSecond: 1_000, outPerSecond: 0))
        #expect(second.diskFreeBytes == 42)
        #expect(fakes.freeCalls == 1)
    }

    @Test func slowReadsRepeatAfterTheirInterval() async {
        let fakes = Fakes()
        let sampler = Sampler(sensors: SensorSet(cpu: fakes, memory: fakes, network: fakes, disk: fakes, power: fakes, temperature: fakes))
        let start = Date(timeIntervalSince1970: 0)
        for second in 0..<21 {
            _ = await sampler.sample(at: start.addingTimeInterval(Double(second)))
        }
        #expect(fakes.freeCalls == 3)
    }
}

@MainActor
struct LiveStoreTests {
    @Test func keepsRecentValuesPerMetric() {
        let store = LiveStore(capacity: 3)
        for i in 0..<4 {
            var snapshot = Snapshot(date: Date(timeIntervalSince1970: Double(i)))
            snapshot.cpuTemperature = Double(i)
            store.ingest(snapshot)
        }
        #expect(store.recent(.cpuTemperature, count: 5) == [1, 2, 3])
        #expect(store.recent(.cpu, count: 2) == [nil, nil])
        #expect(store.latest?.cpuTemperature == 3)
    }
}
