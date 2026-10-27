import Charts
import NadiCore
import SwiftUI

/// Ten minutes of one or two metrics, newest on the right. Two series: the first is drawn in the accent color,
/// the second in the secondary label color.
struct HistoryChart: View {
    struct Series: Identifiable {
        var metric: MetricID
        var name: String
        var id: MetricID { metric }
    }

    /// 600 one-second samples averaged in fives: 120 points keeps redraws cheap while the panel is open.
    static let bucketSize = 5
    static let pointCount = 120

    let store: LiveStore
    let series: [Series]
    var alerting = false

    private struct Point: Identifiable {
        var series: String
        var index: Int
        var value: Double
        var id: String { "\(series)-\(index)" }
    }

    var body: some View {
        let points = makePoints()
        Group {
            if points.isEmpty {
                Text(store.latest == nil || store.recent(series[0].metric, count: 3).count < 3
                     ? "Collecting readings…" : "Not available on this Mac")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Chart(points) { point in
                    AreaMark(
                        x: .value("Time", point.index),
                        y: .value("Value", point.value),
                        series: .value("Series", point.series)
                    )
                    .foregroundStyle(color(for: point.series).opacity(series.count > 1 ? 0 : 0.18))
                    LineMark(
                        x: .value("Time", point.index),
                        y: .value("Value", point.value),
                        series: .value("Series", point.series)
                    )
                    .foregroundStyle(color(for: point.series))
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                }
                .chartXScale(domain: 0...(Self.pointCount - 1))
                .chartYScale(domain: 0...1)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartLegend(.hidden)
            }
        }
        .frame(height: 40)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(series.map(\.name).joined(separator: " and ")) over the last 10 minutes")
    }

    private func color(for name: String) -> Color {
        if alerting { return .red }
        return name == series.first?.name ? .accentColor : .secondary
    }

    /// Values are scaled with the same rules as the menu bar so both read alike.
    private func makePoints() -> [Point] {
        let rating = store.latest?.power?.adapterRatingWatts
        let raw = series.map { store.recent($0.metric, count: Self.pointCount * Self.bucketSize) }
        // Two-series charts share one scale so the lines compare.
        let sharedPeak = raw.flatMap { $0.compactMap { $0 } }.max()
        var points: [Point] = []
        for (s, values) in zip(series, raw) {
            let scaled: [Double?]
            if series.count > 1, let sharedPeak {
                scaled = GraphScale.fractions(values + [sharedPeak], for: s.metric, adapterRatingWatts: rating).dropLast()
            } else {
                scaled = GraphScale.fractions(values, for: s.metric, adapterRatingWatts: rating)
            }
            let averaged = Downsample.average(scaled, bucketSize: Self.bucketSize)
            let offset = Self.pointCount - averaged.count
            for (i, value) in averaged.enumerated() {
                if let value { points.append(Point(series: s.name, index: offset + i, value: value)) }
            }
        }
        return points
    }
}
