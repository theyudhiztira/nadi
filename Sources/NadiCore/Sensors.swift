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
    func gpuCelsius() -> Double?
}

public protocol FanSensor: Sendable {
    func rpm() -> [Double]?
}

public protocol GPUSensor: Sendable {
    /// Busy fraction 0...1.
    func utilization() -> Double?
}

public protocol EnergySensor: Sendable {
    /// Watts averaged since the previous call; the first call may have no GPU figure yet.
    func reading() -> EnergyReading?
}

public protocol ProcessSensor: Sendable {
    func samples() -> [ProcessSample]?
}

public struct SensorSet: Sendable {
    public var cpu: any CPUSensor
    public var memory: any MemorySensor
    public var network: any NetworkSensor
    public var disk: any DiskSensor
    public var power: any PowerSensor
    public var temperature: any TemperatureSensor
    public var fans: any FanSensor
    public var gpu: any GPUSensor
    public var energy: any EnergySensor
    public var processes: any ProcessSensor

    public init(
        cpu: any CPUSensor,
        memory: any MemorySensor,
        network: any NetworkSensor,
        disk: any DiskSensor,
        power: any PowerSensor,
        temperature: any TemperatureSensor,
        fans: any FanSensor,
        gpu: any GPUSensor,
        energy: any EnergySensor,
        processes: any ProcessSensor
    ) {
        self.cpu = cpu
        self.memory = memory
        self.network = network
        self.disk = disk
        self.power = power
        self.temperature = temperature
        self.fans = fans
        self.gpu = gpu
        self.energy = energy
        self.processes = processes
    }
}
