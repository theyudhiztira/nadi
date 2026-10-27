public enum MetricID: String, CaseIterable, Sendable, Codable {
    case cpu
    case memory
    case cpuTemperature
    case power

    public static let menuBarDefaults: [MetricID] = [.cpu, .memory, .cpuTemperature, .power]

    public var label: String {
        switch self {
        case .cpu: "CPU"
        case .memory: "RAM"
        case .cpuTemperature: "Temp"
        case .power: "In"
        }
    }

    /// Placeholder until phase 7 brings user-set alert rules. Value in the metric's own unit.
    public var defaultAlertThreshold: Double? {
        switch self {
        case .cpu: 0.9
        case .memory: 0.9
        case .cpuTemperature: 90
        case .power: nil
        }
    }

    public func isAlerting(_ value: Double?) -> Bool {
        guard let value, let threshold = defaultAlertThreshold else { return false }
        return value >= threshold
    }
}
