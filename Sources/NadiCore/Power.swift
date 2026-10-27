public struct PowerStatus: Sendable, Equatable {
    public var externalConnected: Bool
    public var isCharging: Bool
    public var fullyCharged: Bool
    public var percent: Int?
    public var adapterInputWatts: Double?
    public var adapterRatingWatts: Double?
    public var systemLoadWatts: Double?
    /// Positive while charging, negative while discharging.
    public var batteryWatts: Double?
    public var notChargingReason: Int?
    public var cycleCount: Int?
    public var healthFraction: Double?
    public var timeRemainingMinutes: Int?

    public init(externalConnected: Bool, isCharging: Bool, fullyCharged: Bool = false) {
        self.externalConnected = externalConnected
        self.isCharging = isCharging
        self.fullyCharged = fullyCharged
    }

    /// Adapter input while on AC, system draw while on battery (D6).
    public var menuBarWatts: Double? {
        externalConnected ? adapterInputWatts : systemLoadWatts
    }

    public static func watts(millivolts: Int, milliamps: Int) -> Double {
        Double(millivolts) * Double(milliamps) / 1_000_000
    }

    /// Builds a status from the `AppleSmartBattery` IORegistry properties. Nil when the battery keys are missing.
    public init?(smartBattery p: [String: Any]) {
        guard let external = p["ExternalConnected"] as? Bool else { return nil }
        self.init(
            externalConnected: external,
            isCharging: p["IsCharging"] as? Bool ?? false,
            fullyCharged: p["FullyCharged"] as? Bool ?? false
        )
        percent = Self.int(p["CurrentCapacity"])
        cycleCount = Self.int(p["CycleCount"])
        if let raw = Self.int(p["AppleRawMaxCapacity"]), let design = Self.int(p["DesignCapacity"]), design > 0 {
            healthFraction = Double(raw) / Double(design)
        }
        // 65535 means "still calculating".
        if let minutes = Self.int(p["TimeRemaining"]), minutes < 65535 {
            timeRemainingMinutes = minutes
        }
        if let telemetry = p["PowerTelemetryData"] as? [String: Any] {
            adapterInputWatts = Self.int(telemetry["SystemPowerIn"]).map { Double($0) / 1000 }
            systemLoadWatts = Self.int(telemetry["SystemLoad"]).map { Double($0) / 1000 }
        }
        if let adapter = p["AdapterDetails"] as? [String: Any] {
            adapterRatingWatts = Self.int(adapter["Watts"]).map(Double.init)
        }
        if let charger = p["ChargerData"] as? [String: Any] {
            notChargingReason = Self.int(charger["NotChargingReason"])
        }
        if let mv = Self.int(p["Voltage"]), let ma = Self.int(p["InstantAmperage"]) {
            batteryWatts = Self.watts(millivolts: mv, milliamps: ma)
        }
    }

    /// IORegistry hands back negative amperage as a huge unsigned value; reinterpret it as Int64.
    private static func int(_ any: Any?) -> Int? {
        switch any {
        case let v as Int: v
        case let v as Int64: Int(v)
        case let v as UInt64: Int(Int64(bitPattern: v))
        case let v as Double: Int(v)
        default: nil
        }
    }
}
