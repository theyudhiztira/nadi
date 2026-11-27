import Testing
@testable import NadiCore

struct ChartDataTests {
    @Test func rightAlignsRecentPoints() {
        let points = ChartData.points(
            [[0.1, 0.2, 0.3, 0.4, 0.5]],
            metrics: [.cpu],
            adapterRatingWatts: nil
        )
        #expect(points == [ChartData.Point(series: 0, index: 119, value: 0.3, raw: 0.3)])
    }

    @Test func skipsNilBuckets() {
        let points = ChartData.points(
            [[nil, nil, nil, nil, nil, 0.1, 0.2, 0.3, 0.4, 0.5]],
            metrics: [.cpu],
            adapterRatingWatts: nil
        )
        #expect(points == [ChartData.Point(series: 0, index: 119, value: 0.3, raw: 0.3)])
    }

    @Test func sharesScaleAcrossSeries() {
        let points = ChartData.points(
            [[500_000, 1_000_000], [2_000_000, 1_000_000]],
            metrics: [.networkIn, .networkOut],
            adapterRatingWatts: nil,
            bucketSize: 1,
            pointCount: 2
        )
        #expect(points.map(\.value) == [0.25, 0.5, 1, 0.5])
    }

    @Test func singleSeriesUsesScaledBucketMean() {
        let points = ChartData.points(
            [[0.1, 0.2]],
            metrics: [.cpu],
            adapterRatingWatts: nil,
            bucketSize: 2
        )
        let expected = GraphScale.fractions([0.15], for: .cpu).compactMap { $0 }.first!
        #expect(abs((points.first?.value ?? -1) - expected) < 1e-12)
        #expect(abs((points.first?.raw ?? -1) - 0.15) < 1e-12)
    }
}
