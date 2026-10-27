import Testing
@testable import NadiCore

struct MemoryTests {
    @Test func usedMatchesActivityMonitorFormula() {
        let pages = VMPageCounts(internalPages: 1_000, purgeablePages: 200, wiredPages: 300, compressedPages: 100, pageSize: 16_384)
        #expect(pages.usedBytes == 1_200 * 16_384)
    }

    @Test func purgeableAboveInternalDoesNotUnderflow() {
        let pages = VMPageCounts(internalPages: 10, purgeablePages: 20, wiredPages: 5, compressedPages: 0, pageSize: 4)
        #expect(pages.usedBytes == 20)
    }

    @Test func fraction() {
        #expect(MemoryUsage(usedBytes: 8, totalBytes: 32).fraction == 0.25)
        #expect(MemoryUsage(usedBytes: 8, totalBytes: 0).fraction == 0)
    }
}
