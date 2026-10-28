import Charts
import NadiCore
import SwiftUI

/// Ten minutes of one or two metrics, newest on the right. Two series: the first is drawn in the accent color,
/// the second in the secondary label color. Hovering shows the values at that point.
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
    @ViewState private var hovered: Int?
    @ViewState private var tooltipWidth: CGFloat = 0

    private struct Point: Identifiable {
        var series: String
        var metric: MetricID
        var index: Int
        /// 0...1 on the chart's scale.
        var value: Double
        /// The bucket's average in the metric's own unit, for the hover readout.
        var raw: Double
        var id: String { "\(series)-\(index)" }
    }

    var body: some View {
        let points = makePoints()
        let hoveredPoints = hovered.map { index in points.filter { $0.index == index } } ?? []
        Group {
            if points.isEmpty {
                Text(store.latest == nil || store.recent(series[0].metric, count: 3).count < 3
                     ? "Collecting readings…" : "Not available on this Mac")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Chart {
                    ForEach(points) { point in
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
                    if let index = hoveredPoints.first?.index {
                        RuleMark(x: .value("Time", index))
                            .foregroundStyle(Color.secondary.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1))
                        ForEach(hoveredPoints) { point in
                            PointMark(x: .value("Time", point.index), y: .value("Value", point.value))
                                .foregroundStyle(color(for: point.series))
                                .symbolSize(16)
                        }
                    }
                }
                .chartXScale(domain: 0...(Self.pointCount - 1))
                .chartYScale(domain: 0...1)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartLegend(.hidden)
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        let plot = proxy.plotFrame.map { geometry[$0] } ?? CGRect(origin: .zero, size: geometry.size)
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    guard let x = proxy.value(atX: location.x - plot.minX, as: Double.self) else { return }
                                    let index = min(max(Int(x.rounded()), 0), Self.pointCount - 1)
                                    if index != hovered { hovered = index }
                                case .ended:
                                    hovered = nil
                                }
                            }
                        // Drawn by hand: the panel never activates the app, so system tooltips from .help() don't appear.
                        if let index = hoveredPoints.first?.index, let x = proxy.position(forX: index) {
                            let half = tooltipWidth / 2
                            let center = min(max(plot.minX + x, half), geometry.size.width - half)
                            Text(readout(hoveredPoints, index: index))
                                .font(.system(size: 11).monospacedDigit())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
                                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                                .fixedSize()
                                .onGeometryChange(for: CGFloat.self, of: \.size.width) { tooltipWidth = $0 }
                                .position(x: center, y: -12)
                                .allowsHitTesting(false)
                        }
                    }
                }
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

    /// "42% · 3 min 05 s ago", or with two series "Down 14 KB/s · Up 11 KB/s · now".
    private func readout(_ points: [Point], index: Int) -> String {
        let values = points.map { point in
            // The menu bar's compact fan format ("1.6k") would disagree with the rpm rows under the chart.
            let value = point.metric == .fan
                ? "\(point.raw.formatted(.number.precision(.fractionLength(0)))) rpm"
                : MetricFormatter.format(point.raw, for: point.metric)
            return series.count > 1 ? "\(point.series) \(value)" : value
        }
        return (values + [Self.age(ofIndex: index)]).joined(separator: " · ")
    }

    static func age(ofIndex index: Int) -> String {
        let seconds = (pointCount - 1 - index) * bucketSize
        if seconds == 0 { return "now" }
        if seconds < 60 { return "\(seconds) s ago" }
        let rest = seconds % 60
        return rest == 0 ? "\(seconds / 60) min ago" : "\(seconds / 60) min \(String(format: "%02d", rest)) s ago"
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
            let averagedRaw = Downsample.average(values, bucketSize: Self.bucketSize)
            let offset = Self.pointCount - averaged.count
            for (i, (value, rawValue)) in zip(averaged, averagedRaw).enumerated() {
                if let value, let rawValue {
                    points.append(Point(series: s.name, metric: s.metric, index: offset + i, value: value, raw: rawValue))
                }
            }
        }
        return points
    }
}
