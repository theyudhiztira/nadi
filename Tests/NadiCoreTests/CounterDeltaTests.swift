import Testing
@testable import NadiCore

struct CounterDeltaTests {
    @Test func forward() {
        #expect(CounterDelta.delta(from: 100, to: 150) == 50)
        #expect(CounterDelta.delta(from: 7, to: 7) == 0)
    }

    @Test func wrapsAt32Bits() {
        let max32 = UInt64(UInt32.max)
        #expect(CounterDelta.delta(from: max32 - 9, to: 5, bitWidth: 32) == 15)
    }

    @Test func largeDropIsReset() {
        #expect(CounterDelta.delta(from: 3_000_000_000, to: 2_000_000_000, bitWidth: 32) == nil)
    }

    @Test func sixtyFourBitDropIsReset() {
        #expect(CounterDelta.delta(from: 500, to: 10) == nil)
    }

    @Test func byteRates() {
        let rates = ByteCounters.rates(
            from: ByteCounters(inBytes: 1_000, outBytes: 0),
            to: ByteCounters(inBytes: 3_000, outBytes: 500),
            seconds: 2
        )
        #expect(rates == ByteRates(inPerSecond: 1_000, outPerSecond: 250))
        #expect(ByteCounters.rates(from: .init(inBytes: 9, outBytes: 0), to: .init(inBytes: 1, outBytes: 0), seconds: 1) == nil)
        #expect(ByteCounters.rates(from: .init(inBytes: 0, outBytes: 0), to: .init(inBytes: 1, outBytes: 0), seconds: 0) == nil)
    }
}
