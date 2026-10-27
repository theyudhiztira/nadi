// Sensor seams. Real readers live in NadiSensors; tests use fakes. Every reader returns nil on failure.

public protocol CPUSensor: Sendable {
    func ticks() -> [CPUTicks]?
}

public protocol MemorySensor: Sendable {
    func usage() -> MemoryUsage?
}

public protocol NetworkSensor: Sendable {
    /// Cumulative bytes across all non-loopback interfaces, in = received.
    func counters() -> ByteCounters?
}

public protocol DiskSensor: Sendable {
    /// Cumulative bytes, in = read, out = written.
    func counters() -> ByteCounters?
    func freeBytes() -> Int64?
}

public protocol PowerSensor: Sendable {
    func status() -> PowerStatus?
}

public protocol TemperatureSensor: Sendable {
    func cpuCelsius() -> Double?
}

public struct SensorSet: Sendable {
    public var cpu: any CPUSensor
    public var memory: any MemorySensor
    public var network: any NetworkSensor
    public var disk: any DiskSensor
    public var power: any PowerSensor
    public var temperature: any TemperatureSensor

    public init(
        cpu: any CPUSensor,
        memory: any MemorySensor,
        network: any NetworkSensor,
        disk: any DiskSensor,
        power: any PowerSensor,
        temperature: any TemperatureSensor
    ) {
        self.cpu = cpu
        self.memory = memory
        self.network = network
        self.disk = disk
        self.power = power
        self.temperature = temperature
    }
}
