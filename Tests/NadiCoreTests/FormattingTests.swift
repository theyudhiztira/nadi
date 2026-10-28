import Testing
@testable import NadiCore

struct FormattingTests {
    @Test func percentages() {
        #expect(MetricFormatter.format(0.234, for: .cpu) == "23%")
        #expect(MetricFormatter.format(1.4, for: .memory) == "100%")
        #expect(MetricFormatter.format(-0.1, for: .cpu) == "0%")
    }

    @Test func temperature() {
        #expect(MetricFormatter.format(54.6, for: .cpuTemperature) == "55°")
        #expect(MetricFormatter.format(100, for: .cpuTemperature, temperatureUnit: .fahrenheit) == "212°")
    }

    @Test func watts() {
        #expect(MetricFormatter.format(41.05, for: .power) == "41W")
        #expect(MetricFormatter.format(4.24, for: .power) == "4.2W")
        #expect(MetricFormatter.format(9.96, for: .power) == "10W")
    }

    @Test func fanAndRates() {
        #expect(MetricFormatter.format(850, for: .fan) == "850")
        #expect(MetricFormatter.format(2_683, for: .fan) == "2.7k")
        #expect(MetricFormatter.format(1_500_000, for: .networkIn) == "1.5 MB/s")
    }

    @Test func missingValue() {
        #expect(MetricFormatter.format(nil, for: .cpu) == "--")
        #expect(MetricFormatter.format(.nan, for: .power) == "--")
    }

    @Test func unrepresentableValuesDoNotTrap() {
        #expect(MetricFormatter.watts(.nan) == "--")
        #expect(MetricFormatter.watts(.infinity) == "--")
        #expect(MetricFormatter.watts(1e30) == "--")
        #expect(MetricFormatter.format(-1e30, for: .fan) == "--")
        #expect(MetricFormatter.format(1e30, for: .cpuTemperature) == "--")
    }

    @Test func bytes() {
        #expect(MetricFormatter.bytes(512) == "512 B")
        #expect(MetricFormatter.bytes(1_260) == "1.3 KB")
        #expect(MetricFormatter.bytesPerSecond(42_000_000) == "42 MB/s")
        #expect(MetricFormatter.bytes(34_359_738_368, binary: true) == "32 GB")
    }

    @Test func graphScale() {
        #expect(GraphScale.fractions([0.5, nil], for: .cpu) == [0.5, nil])
        #expect(GraphScale.fractions([65, 20, 120], for: .cpuTemperature) == [0.5, 0, 1])
        #expect(GraphScale.fractions([30], for: .power, adapterRatingWatts: 60) == [0.5])
        #expect(GraphScale.fractions([5], for: .power) == [0.5])
    }
}
