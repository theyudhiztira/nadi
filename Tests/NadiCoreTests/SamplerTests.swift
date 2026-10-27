import Foundation
import Testing
@testable import NadiCore

private final class Fakes: CPUSensor, MemorySensor, NetworkSensor, DiskSensor, PowerSensor, TemperatureSensor, FanSensor, GPUSensor, EnergySensor, ProcessSensor, @unchecked Sendable {
    var queuedTicks: [[CPUTicks]] = []
    var network: [ByteCounters] = []
    var freeCalls = 0

    func ticks() -> [CPUTicks]? { queuedTicks.isEmpty ? nil : queuedTicks.removeFirst() }
    func usage() -> MemoryUsage? { MemoryUsage(usedBytes: 1, totalBytes: 4) }
    func counters() -> ByteCounters? { network.isEmpty ? nil : network.removeFirst() }
    func freeBytes() -> Int64? { freeCalls += 1; return 42 }
    func status() -> PowerStatus? { nil }
    func cpuCelsius() -> Double? { 55 }
    func gpuCelsius() -> Double? { nil }
    func rpm() -> [Double]? { [1_200, 1_500] }
    func utilization() -> Double? { 0.3 }
    func reading() -> EnergyReading? { EnergyReading(cpuWatts: 4) }
    var processTimes: [UInt64] = []
    func samples() -> [ProcessSample]? {
        processTimes.isEmpty ? nil : [ProcessSample(pid: 7, name: "busy", cpuNanoseconds: processTimes.removeFirst(), memoryBytes: 1)]
    }

    var set: SensorSet {
        SensorSet(cpu: self, memory: self, network: self, disk: self, power: self, temperature: self, fans: self, gpu: self, energy: self, processes: self)
    }
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
        let sampler = Sampler(sensors: fakes.set)
        let start = Date(timeIntervalSince1970: 0)

        let first = await sampler.sample(at: start)
        #expect(first.cpu == nil)
        #expect(first.network == nil)
        #expect(first.memory?.fraction == 0.25)
        #expect(first.cpuTemperature == 55)
        #expect(first.value(.fan) == 1_500)
        #expect(first.value(.gpu) == 0.3)
        #expect(first.value(.cpuPower) == 4)

        let second = await sampler.sample(at: start.addingTimeInterval(2))
        #expect(second.cpu?.total == 0.25)
        #expect(second.network == ByteRates(inPerSecond: 1_000, outPerSecond: 0))
        #expect(second.diskFreeBytes == 42)
        #expect(fakes.freeCalls == 1)
    }

    @Test func slowReadsRepeatAfterTheirInterval() async {
        let fakes = Fakes()
        let sampler = Sampler(sensors: fakes.set)
        let start = Date(timeIntervalSince1970: 0)
        for second in 0..<21 {
            _ = await sampler.sample(at: start.addingTimeInterval(Double(second)))
        }
        #expect(fakes.freeCalls == 3)
    }
}

struct SamplerProcessTests {
    @Test func processesOnlyWhileEnabled() async {
        let fakes = Fakes()
        fakes.processTimes = [0, 500_000_000, 1_000_000_000]
        let sampler = Sampler(sensors: fakes.set)
        let start = Date(timeIntervalSince1970: 0)
        #expect(await sampler.sample(at: start).processes == nil)
        await sampler.setDetailed(true)
        #expect(await sampler.sample(at: start.addingTimeInterval(1)).processes == nil)
        let usage = await sampler.sample(at: start.addingTimeInterval(2)).processes
        #expect(usage?.first?.cpu == 0.5)
        #expect(fakes.processTimes == [1_000_000_000])
    }
}

struct SamplerTierTests {
    @Test func panelOnlySensorsReadEveryFifthTickWhileClosed() async {
        let fakes = Fakes()
        let sampler = Sampler(sensors: fakes.set, menuBarMetrics: [.cpu])
        let start = Date(timeIntervalSince1970: 0)
        var fanReadings = 0
        for second in 0..<10 {
            if await sampler.sample(at: start.addingTimeInterval(Double(second))).fanRPM != nil { fanReadings += 1 }
        }
        #expect(fanReadings == 2)

        await sampler.setDetailed(true)
        #expect(await sampler.sample(at: start.addingTimeInterval(10.2)).fanRPM != nil)
        #expect(await sampler.sample(at: start.addingTimeInterval(11.2)).fanRPM != nil)
    }

    @Test func menuBarMetricsReadEveryTick() async {
        let fakes = Fakes()
        let sampler = Sampler(sensors: fakes.set, menuBarMetrics: [.fan])
        let start = Date(timeIntervalSince1970: 0)
        for second in 0..<3 {
            #expect(await sampler.sample(at: start.addingTimeInterval(Double(second))).fanRPM != nil)
        }
    }
}

struct PowerDisplayTests {
    private func snapshot(charging: Bool, input: Double, battery: Double) -> Snapshot {
        var s = Snapshot(date: Date())
        var p = PowerStatus(externalConnected: true, isCharging: charging)
        p.adapterInputWatts = input
        p.adapterRatingWatts = 45
        p.batteryWatts = battery
        p.systemLoadWatts = 30
        s.power = p
        return s
    }

    @Test func chargingWellAndSlow() {
        #expect(snapshot(charging: true, input: 40, battery: 22).powerDisplay == .charging(watts: 22, slow: false))
        #expect(snapshot(charging: true, input: 15, battery: 4).powerDisplay == .charging(watts: 4, slow: true))
    }

    @Test func notChargingShowsSystemDraw() {
        var s = snapshot(charging: false, input: 35, battery: -1)
        #expect(s.powerDisplay == .consuming(watts: 30))
        s.power?.systemLoadWatts = nil
        s.energy = EnergyReading(systemWatts: 38)
        #expect(s.powerDisplay == .consuming(watts: 38))
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
