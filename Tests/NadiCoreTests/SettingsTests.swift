import Foundation
import Testing
@testable import NadiCore

struct SettingsTests {
    @Test func defaultsMatchCurrentBehavior() {
        #expect(Settings.default.menuBarMetrics == MetricID.menuBarDefaults)
        #expect(Settings.default.interval == 1)
        #expect(Settings.default.temperatureUnit == .celsius)
    }

    @Test func roundTripsThroughJSON() throws {
        let settings = Settings(menuBarMetrics: [.cpu, .fan], interval: 2, temperatureUnit: .fahrenheit)
        #expect(try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(settings)) == settings)
    }

    @Test func ignoresExtraKeysAndDefaultsBadFields() throws {
        let data = Data(#"{"menuBarMetrics":"bad","interval":"bad","temperatureUnit":"kelvin","alerts":{},"historyEnabled":true}"#.utf8)
        #expect(try JSONDecoder().decode(Settings.self, from: data) == .default)
    }

    @Test func missingFieldsUseDefaults() throws {
        let data = Data(#"{"interval":2,"historyRetentionDays":30}"#.utf8)
        let decoded = try JSONDecoder().decode(Settings.self, from: data)
        #expect(decoded.menuBarMetrics == MetricID.menuBarDefaults)
        #expect(decoded.interval == 2)
        #expect(decoded.temperatureUnit == .celsius)
    }

    @Test func clampsIntervalAndDropsDuplicateMetrics() throws {
        let data = Data(#"{"menuBarMetrics":["cpu","cpu","fan"],"interval":60,"temperatureUnit":"fahrenheit"}"#.utf8)
        let decoded = try JSONDecoder().decode(Settings.self, from: data)
        #expect(decoded.menuBarMetrics == [.cpu, .fan])
        #expect(decoded.interval == 5)
        #expect(decoded.temperatureUnit == .fahrenheit)
        let low = try JSONDecoder().decode(Settings.self, from: Data(#"{"interval":0.1}"#.utf8))
        #expect(low.interval == 0.5)
    }

    @Test func allowsAnEmptyMetricList() {
        #expect(Settings(menuBarMetrics: [], interval: 1, temperatureUnit: .celsius).menuBarMetrics.isEmpty)
    }
}
