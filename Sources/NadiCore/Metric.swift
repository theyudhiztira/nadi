public enum MetricID: String, CaseIterable, Sendable, Codable {
    case cpu
    case memory
    case cpuTemperature
    case power
    case gpu
    case gpuTemperature
    case fan
    case cpuPower
    case gpuPower
    case networkIn
    case networkOut
    case diskRead
    case diskWrite

    public static let menuBarDefaults: [MetricID] = [.cpu, .memory, .cpuTemperature, .power]

    public var label: String {
        switch self {
        case .cpu: "CPU"
        case .memory: "RAM"
        case .cpuTemperature: "Temp"
        case .power: "In"
        case .gpu: "GPU"
        case .gpuTemperature: "GPU°"
        case .fan: "Fan"
        case .cpuPower: "CPU W"
        case .gpuPower: "GPU W"
        case .networkIn: "Down"
        case .networkOut: "Up"
        case .diskRead: "Read"
        case .diskWrite: "Write"
        }
    }

    /// Placeholder until phase 7 brings user-set alert rules. Value in the metric's own unit.
    public var defaultAlertThreshold: Double? {
        switch self {
        case .cpu, .memory: 0.9
        case .cpuTemperature, .gpuTemperature: 90
        default: nil
        }
    }

    public func isAlerting(_ value: Double?) -> Bool {
        guard let value, let threshold = defaultAlertThreshold else { return false }
        return value >= threshold
    }
}
