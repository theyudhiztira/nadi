import Testing
@testable import NadiCore

struct PowerTests {
    @Test func wattsFromMillivoltsAndMilliamps() {
        #expect(PowerStatus.watts(millivolts: 12_500, milliamps: 2_000) == 25)
        #expect(PowerStatus.watts(millivolts: 12_000, milliamps: -1_500) == -18)
    }

    @Test func nonFiniteNumbersAreDropped() throws {
        let props: [String: Any] = ["ExternalConnected": true, "CurrentCapacity": Double.nan, "CycleCount": 1e30]
        let status = try #require(PowerStatus(smartBattery: props))
        #expect(status.percent == nil)
        #expect(status.cycleCount == nil)
    }

    @Test func parsesSmartBatteryOnAC() throws {
        let props: [String: Any] = [
            "ExternalConnected": true,
            "IsCharging": false,
            "FullyCharged": false,
            "CurrentCapacity": 80,
            "CycleCount": 312,
            "AppleRawMaxCapacity": 4_500,
            "DesignCapacity": 5_000,
            "TimeRemaining": 65_535,
            "Voltage": 12_600,
            "InstantAmperage": UInt64(bitPattern: -500),
            "PowerTelemetryData": ["SystemPowerIn": 41_050, "SystemLoad": 42_764],
            "AdapterDetails": ["Watts": 45],
            "ChargerData": ["NotChargingReason": 16_777_216],
        ]
        let status = try #require(PowerStatus(smartBattery: props))
        #expect(status.externalConnected)
        #expect(status.percent == 80)
        #expect(status.cycleCount == 312)
        #expect(status.healthFraction == 0.9)
        #expect(status.timeRemainingMinutes == nil)
        #expect(status.adapterInputWatts == 41.05)
        #expect(status.adapterRatingWatts == 45)
        #expect(status.notChargingReason == 0x100_0000)
        #expect(status.batteryWatts == -6.3)
        #expect(status.menuBarWatts == 41.05)
    }

    @Test func onBatteryShowsSystemLoad() throws {
        let status = try #require(PowerStatus(smartBattery: [
            "ExternalConnected": false,
            "PowerTelemetryData": ["SystemPowerIn": 0, "SystemLoad": 9_500],
        ]))
        #expect(status.menuBarWatts == 9.5)
    }

    @Test func missingBatteryIsNil() {
        #expect(PowerStatus(smartBattery: [:]) == nil)
    }
}
