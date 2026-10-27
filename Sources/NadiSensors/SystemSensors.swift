import NadiCore

extension SensorSet {
    /// The real readers for this Mac.
    public static func system() -> SensorSet {
        SensorSet(
            cpu: CPUReader(),
            memory: MemoryReader(),
            network: NetworkReader(),
            disk: DiskReader(),
            power: PowerReader(),
            temperature: HIDTemperatureReader()
        )
    }
}
