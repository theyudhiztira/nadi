import Testing
@testable import NadiCore

struct CPULoadTests {
    @Test func busyFractionPerCoreAndTotal() throws {
        let before = [CPUTicks(user: 0, system: 0, idle: 0, nice: 0), CPUTicks(user: 0, system: 0, idle: 0, nice: 0)]
        let after = [CPUTicks(user: 30, system: 10, idle: 60, nice: 0), CPUTicks(user: 0, system: 0, idle: 100, nice: 0)]
        let load = try #require(CPULoad(from: before, to: after))
        #expect(load.perCore == [0.4, 0])
        #expect(load.total == 0.2)
    }

    @Test func survivesTickWrap() throws {
        let before = [CPUTicks(user: .max - 9, system: 0, idle: 0, nice: 0)]
        let after = [CPUTicks(user: 10, system: 0, idle: 20, nice: 0)]
        let load = try #require(CPULoad(from: before, to: after))
        #expect(load.total == 0.5)
    }

    @Test func coreCountChangeIsNil() {
        #expect(CPULoad(from: [], to: [CPUTicks(user: 1, system: 0, idle: 0, nice: 0)]) == nil)
    }

    @Test func noElapsedTicksIsZero() throws {
        let t = [CPUTicks(user: 5, system: 5, idle: 5, nice: 5)]
        #expect(try #require(CPULoad(from: t, to: t)).total == 0)
    }
}
