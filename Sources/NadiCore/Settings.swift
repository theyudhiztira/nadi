import Foundation
import Observation

public struct Settings: Codable, Sendable, Equatable {
    public var menuBarMetrics: [MetricID]
    public var interval: TimeInterval
    public var temperatureUnit: TemperatureUnit

    public static let `default` = Settings(
        menuBarMetrics: MetricID.menuBarDefaults,
        interval: 1,
        temperatureUnit: .celsius
    )

    public init(menuBarMetrics: [MetricID], interval: TimeInterval, temperatureUnit: TemperatureUnit) {
        self.menuBarMetrics = Self.unique(menuBarMetrics)
        self.interval = min(max(interval, 0.5), 5)
        self.temperatureUnit = temperatureUnit
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self.default
        let metrics = (try? container.decode([MetricID].self, forKey: .menuBarMetrics)) ?? defaults.menuBarMetrics
        let interval = (try? container.decode(TimeInterval.self, forKey: .interval)) ?? defaults.interval
        let unit = (try? container.decode(TemperatureUnit.self, forKey: .temperatureUnit)) ?? defaults.temperatureUnit
        self.init(menuBarMetrics: metrics, interval: interval, temperatureUnit: unit)
    }

    private static func unique(_ metrics: [MetricID]) -> [MetricID] {
        var seen = Set<MetricID>()
        return metrics.filter { seen.insert($0).inserted }
    }
}

@MainActor
@Observable
public final class SettingsStore {
    public private(set) var settings: Settings
    private let defaults: UserDefaults
    public static let key = "NadiSettings.v1"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(Settings.self, from: data) {
            settings = decoded
        } else {
            settings = .default
        }
    }

    public func update(_ change: (inout Settings) -> Void) {
        var next = settings
        change(&next)
        next.interval = min(max(next.interval, 0.5), 5)
        next.menuBarMetrics = Settings(menuBarMetrics: next.menuBarMetrics, interval: next.interval,
                                       temperatureUnit: next.temperatureUnit).menuBarMetrics
        guard next != settings else { return }
        settings = next
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
