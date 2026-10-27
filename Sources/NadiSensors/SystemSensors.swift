import NadiCore

extension SensorSet {
    /// The real readers for this Mac.
    public static func system() -> SensorSet {
        let smcKeys = SMC().map { $0.allKeys() } ?? []
        return SensorSet(
            cpu: CPUReader(),
            memory: MemoryReader(),
            network: NetworkReader(),
            disk: DiskReader(),
            power: PowerReader(),
            temperature: TemperatureReader(smcKeys: smcKeys),
            fans: FanReader(),
            gpu: GPUReader(),
            energy: EnergyReader()
        )
    }
}
