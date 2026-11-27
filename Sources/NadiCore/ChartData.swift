public enum ChartData {
    public struct Point: Sendable, Equatable {
        public let series: Int
        public let index: Int
        /// 0...1 on the chart's scale.
        public let value: Double
        /// The bucket's average in the metric's own unit, for the hover readout.
        public let raw: Double

        public init(series: Int, index: Int, value: Double, raw: Double) {
            self.series = series
            self.index = index
            self.value = value
            self.raw = raw
        }
    }

    /// Values are scaled with the same rules as the menu bar so both read alike.
    public static func points(
        _ raw: [[Double?]],
        metrics: [MetricID],
        adapterRatingWatts: Double?,
        bucketSize: Int = 5,
        pointCount: Int = 120
    ) -> [Point] {
        // Two-series charts share one scale so the lines compare.
        let sharedPeak = raw.flatMap { $0.compactMap { $0 } }.max()
        var points: [Point] = []
        for (series, pair) in zip(raw, metrics).enumerated() {
            let (values, metric) = pair
            let scaled: [Double?]
            if metrics.count > 1, let sharedPeak {
                scaled = GraphScale.fractions(values + [sharedPeak], for: metric, adapterRatingWatts: adapterRatingWatts).dropLast()
            } else {
                scaled = GraphScale.fractions(values, for: metric, adapterRatingWatts: adapterRatingWatts)
            }
            let averaged = Downsample.average(scaled, bucketSize: bucketSize)
            let averagedRaw = Downsample.average(values, bucketSize: bucketSize)
            let offset = pointCount - averaged.count
            for (index, pair) in zip(averaged, averagedRaw).enumerated() {
                if let value = pair.0, let raw = pair.1 {
                    points.append(Point(series: series, index: offset + index, value: value, raw: raw))
                }
            }
        }
        return points
    }
}
