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
    var temperatureUnit: TemperatureUnit = .celsius

    var body: some View {
        let raw = series.map { store.recent($0.metric, count: Self.pointCount * Self.bucketSize) }
        let points = ChartData.points(
            raw,
            metrics: series.map(\.metric),
            adapterRatingWatts: store.latest?.power?.adapterRatingWatts,
            bucketSize: Self.bucketSize,
            pointCount: Self.pointCount
        )
        Group {
            if points.isEmpty {
                Text(store.latest == nil || store.recent(series[0].metric, count: 3).count < 3
                     ? "Collecting…" : "Unavailable")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.panelSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Canvas { context, size in
                    let lineWidth: CGFloat = 1.25
                    let inset = lineWidth / 2
                    let baselineY = size.height - 0.25
                    var baseline = Path()
                    baseline.move(to: CGPoint(x: 0, y: baselineY))
                    baseline.addLine(to: CGPoint(x: size.width, y: baselineY))
                    context.stroke(baseline, with: .color(Color.primary.opacity(0.11)), lineWidth: 0.5)

                    for seriesIndex in series.indices {
                        let color = Self.color(for: seriesIndex)
                        let seriesPoints = points.filter { $0.series == seriesIndex }
                        for segment in Self.segments(seriesPoints) {
                            guard let first = segment.first, let last = segment.last else { continue }
                            let path = Self.path(for: segment, size: size, inset: inset)
                            if series.count == 1 && seriesIndex == 0 {
                                var area = path
                                area.addLine(to: CGPoint(x: Self.x(for: last.index, width: size.width), y: baselineY))
                                area.addLine(to: CGPoint(x: Self.x(for: first.index, width: size.width), y: baselineY))
                                area.closeSubpath()
                                context.fill(area, with: .color(color.opacity(0.10)))
                            }
                            context.stroke(path, with: .color(color), lineWidth: lineWidth)
                        }
                    }
                }
                .overlay {
                    HoverLayer(
                        points: points,
                        series: series,
                        pointCount: Self.pointCount,
                        readout: { readout(points, index: $0) }
                    )
                }
            }
        }
        .frame(height: 46)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(series.map(\.name).joined(separator: " and ")) over the last 10 minutes")
    }

    private static func color(for series: Int) -> Color {
        series == 0 ? .accentColor : .panelSecondary
    }

    private static func segments(_ points: [ChartData.Point]) -> [[ChartData.Point]] {
        var result: [[ChartData.Point]] = []
        var segment: [ChartData.Point] = []
        for point in points {
            if let last = segment.last, point.index != last.index + 1 {
                result.append(segment)
                segment = []
            }
            segment.append(point)
        }
        if !segment.isEmpty { result.append(segment) }
        return result
    }

    private static func path(for points: [ChartData.Point], size: CGSize, inset: CGFloat) -> Path {
        var path = Path()
        for (index, point) in points.enumerated() {
            let position = CGPoint(
                x: x(for: point.index, width: size.width),
                y: size.height - inset - CGFloat(point.value) * (size.height - inset * 2)
            )
            if index == 0 { path.move(to: position) } else { path.addLine(to: position) }
        }
        return path
    }

    private static func x(for index: Int, width: CGFloat) -> CGFloat {
        CGFloat(index) / CGFloat(pointCount - 1) * width
    }

    /// "42% · 3 min 05 s ago", or with two series "Down 14 KB/s · Up 11 KB/s · now".
    private func readout(_ points: [ChartData.Point], index: Int) -> String {
        let values = points.filter { $0.index == index }.map { point in
            let item = series[point.series]
            // The menu bar's compact fan format ("1.6k") would disagree with the rpm rows under the chart.
            let value = item.metric == .fan
                ? "\(point.raw.formatted(.number.precision(.fractionLength(0)))) rpm"
                : MetricFormatter.format(point.raw, for: item.metric, temperatureUnit: temperatureUnit)
            return series.count > 1 ? "\(item.name) \(value)" : value
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

    private struct HoverLayer: View {
        let points: [ChartData.Point]
        let series: [Series]
        let pointCount: Int
        let readout: (Int) -> String
        @ViewState private var hovered: Int?
        @ViewState private var tooltipSize: CGSize = .zero

        var body: some View {
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                guard geometry.size.width > 0 else { return }
                                let x = location.x / geometry.size.width * CGFloat(pointCount - 1)
                                let index = min(max(Int(x.rounded()), 0), pointCount - 1)
                                if index != hovered { hovered = index }
                            case .ended:
                                hovered = nil
                            }
                        }
                    Canvas { context, size in
                        guard let hovered else { return }
                        let hoveredPoints = points.filter { $0.index == hovered }
                        guard !hoveredPoints.isEmpty else { return }
                        let x = CGFloat(hovered) / CGFloat(pointCount - 1) * size.width
                        var rule = Path()
                        rule.move(to: CGPoint(x: x, y: 0))
                        rule.addLine(to: CGPoint(x: x, y: size.height))
                        context.stroke(rule, with: .color(Color.panelSecondary.opacity(0.5)), lineWidth: 1)
                        for point in hoveredPoints {
                            let y = size.height - 0.625 - CGFloat(point.value) * (size.height - 1.25)
                            let dot = CGRect(x: x - 2, y: y - 2, width: 4, height: 4)
                            context.fill(Path(ellipseIn: dot), with: .color(HistoryChart.color(for: point.series)))
                        }
                    }
                    .allowsHitTesting(false)
                    // Drawn by hand: the panel never activates the app, so system tooltips from .help() don't appear.
                    if let hovered, points.contains(where: { $0.index == hovered }) {
                        let x = CGFloat(hovered) / CGFloat(pointCount - 1) * geometry.size.width
                        let halfWidth = tooltipSize.width / 2
                        let centerX = min(max(x, halfWidth), geometry.size.width - halfWidth)
                        let centerY = min(max(tooltipSize.height / 2, 8), geometry.size.height - tooltipSize.height / 2)
                        Text(readout(hovered))
                            .font(.system(size: 11).monospacedDigit())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
                            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                            .fixedSize()
                            .onGeometryChange(for: CGSize.self, of: \.size) { tooltipSize = $0 }
                            .position(x: centerX, y: centerY)
                            .allowsHitTesting(false)
                    }
                }
            }
        }
    }
}
