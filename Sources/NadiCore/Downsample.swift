public enum Downsample {
    /// Averages consecutive runs of `bucketSize` samples, ignoring nils; a bucket of only nils stays nil.
    /// Leftover samples at the start form a smaller first bucket so the newest bucket is always full.
    public static func average(_ values: [Double?], bucketSize: Int) -> [Double?] {
        precondition(bucketSize > 0)
        guard bucketSize > 1 else { return values }
        var result: [Double?] = []
        var start = values.count % bucketSize
        if start > 0 { result.append(mean(values[0..<start])) }
        while start < values.count {
            result.append(mean(values[start..<start + bucketSize]))
            start += bucketSize
        }
        return result
    }

    private static func mean(_ slice: ArraySlice<Double?>) -> Double? {
        let present = slice.compactMap { $0 }
        return present.isEmpty ? nil : present.reduce(0, +) / Double(present.count)
    }
}
