import Testing
@testable import NadiCore

struct RingBufferTests {
    @Test func keepsOrderBeforeFull() {
        var buffer = RingBuffer<Int>(capacity: 3)
        buffer.append(1)
        buffer.append(2)
        #expect(buffer.elements == [1, 2])
        #expect(buffer.last == 2)
    }

    @Test func dropsOldestWhenFull() {
        var buffer = RingBuffer<Int>(capacity: 3)
        for i in 1...5 { buffer.append(i) }
        #expect(buffer.elements == [3, 4, 5])
        #expect(buffer.count == 3)
        #expect(buffer.last == 5)
        #expect(buffer.suffix(2) == [4, 5])
        #expect(buffer.suffix(10) == [3, 4, 5])
    }

    @Test func emptyHasNoLast() {
        #expect(RingBuffer<Int>(capacity: 2).last == nil)
    }
}
