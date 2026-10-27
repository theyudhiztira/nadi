import Testing
@testable import NadiCore

struct ProcessTests {
    private let samples = [
        ProcessSample(pid: 1, name: "a", cpuNanoseconds: 3_000_000_000, memoryBytes: 100),
        ProcessSample(pid: 2, name: "b", cpuNanoseconds: 1_500_000_000, memoryBytes: 900),
        ProcessSample(pid: 3, name: "new", cpuNanoseconds: 9_000_000_000, memoryBytes: 50),
    ]

    @Test func cpuShareSincePreviousReading() {
        let usage = TopProcesses.usage(previous: [1: 1_000_000_000, 2: 1_000_000_000], current: samples, seconds: 1)
        #expect(usage.map(\.pid) == [1, 2])
        #expect(usage[0].cpu == 2)
        #expect(usage[1].cpu == 0.5)
    }

    @Test func ranking() {
        let usage = [
            ProcessUsage(pid: 1, name: "a", cpu: 2, memoryBytes: 100),
            ProcessUsage(pid: 2, name: "b", cpu: 0.5, memoryBytes: 900),
            ProcessUsage(pid: 3, name: "c", cpu: 1, memoryBytes: 300),
        ]
        #expect(TopProcesses.top(2, of: usage, by: .cpu).map(\.pid) == [1, 3])
        #expect(TopProcesses.top(2, of: usage, by: .memory).map(\.pid) == [2, 3])
    }

    @Test func zeroElapsedGivesNothing() {
        #expect(TopProcesses.usage(previous: [1: 0], current: samples, seconds: 0).isEmpty)
    }
}

struct DownsampleTests {
    @Test func averagesBucketsNewestFull() {
        #expect(Downsample.average([1, 2, 3, 4, 5], bucketSize: 2) == [1, 2.5, 4.5])
    }

    @Test func nilsIgnoredAndAllNilBucketStaysNil() {
        #expect(Downsample.average([nil, 4, nil, nil], bucketSize: 2) == [4, nil])
    }

    @Test func bucketOfOneIsIdentity() {
        #expect(Downsample.average([1, nil], bucketSize: 1) == [1, nil])
    }
}
