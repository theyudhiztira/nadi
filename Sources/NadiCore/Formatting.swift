import Foundation

public enum TemperatureUnit: String, Sendable, Codable {
    case celsius
    case fahrenheit
}

public enum MetricFormatter {
    public static let missing = "--"

    public static func format(_ value: Double?, for metric: MetricID, temperatureUnit: TemperatureUnit = .celsius) -> String {
        guard let value, value.isFinite else { return missing }
        switch metric {
        case .cpu, .memory, .gpu:
            return "\(Int((min(max(value, 0), 1) * 100).rounded()))%"
        case .cpuTemperature, .gpuTemperature:
            let shown = temperatureUnit == .celsius ? value : value * 9 / 5 + 32
            return "\(Int(shown.rounded()))°"
        case .power, .cpuPower, .gpuPower:
            return watts(value)
        case .fan:
            return value < 999.5 ? "\(Int(value.rounded()))" : String(format: "%.1fk", value / 1000)
        case .networkIn, .networkOut, .diskRead, .diskWrite, .network:
            return bytesPerSecond(value)
        }
    }

    /// Whole watts from 10 W up, one decimal below.
    public static func watts(_ value: Double) -> String {
        let v = max(value, 0)
        return v < 9.95 ? String(format: "%.1fW", v) : "\(Int(v.rounded()))W"
    }

    /// Decimal units, matching Activity Monitor: 999 KB/s, 1.2 MB/s.
    public static func bytesPerSecond(_ value: Double) -> String {
        bytes(value) + "/s"
    }

    /// Memory sizes use binary units like Activity Monitor (32 GB of RAM is 32 GiB); traffic uses decimal.
    public static func bytes(_ value: Double, binary: Bool = false) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        let base: Double = binary ? 1024 : 1000
        var v = max(value, 0)
        var i = 0
        while v >= base - 0.5 && i < units.count - 1 {
            v /= base
            i += 1
        }
        if i == 0 || v >= 9.95 { return "\(Int(v.rounded())) \(units[i])" }
        return String(format: "%.1f %@", v, units[i])
    }
}

public enum GraphScale {
    /// Maps raw samples to 0...1 bar heights. Nil samples stay nil.
    public static func fractions(_ values: [Double?], for metric: MetricID, adapterRatingWatts: Double? = nil) -> [Double?] {
        let range: ClosedRange<Double>
        let peak = values.compactMap { $0 }.max() ?? 0
        switch metric {
        case .cpu, .memory, .gpu:
            range = 0...1
        case .cpuTemperature, .gpuTemperature:
            range = 30...100
        case .power:
            range = 0...max(adapterRatingWatts ?? 0, peak, 10)
        case .cpuPower, .gpuPower:
            range = 0...max(peak, 10)
        case .fan:
            range = 0...max(peak, 6000)
        case .networkIn, .networkOut, .diskRead, .diskWrite, .network:
            // Scale to the busiest recent second, but never below 1 MB/s so idle chatter stays flat.
            range = 0...max(peak, 1_000_000)
        }
        let span = range.upperBound - range.lowerBound
        return values.map { value in
            value.map { min(max(($0 - range.lowerBound) / span, 0), 1) }
        }
    }
}
