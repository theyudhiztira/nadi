import Foundation
import Observation

/// The last few minutes of samples, observed by the menu bar and (later) the panel.
@MainActor
@Observable
public final class LiveStore {
    public private(set) var latest: Snapshot?
    private var history: [MetricID: RingBuffer<Double?>]

    /// 600 samples is 10 minutes at the default 1 s interval.
    public init(capacity: Int = 600) {
        history = Dictionary(uniqueKeysWithValues: MetricID.allCases.map { ($0, RingBuffer(capacity: capacity)) })
    }

    public func ingest(_ snapshot: Snapshot) {
        for metric in MetricID.allCases {
            history[metric]?.append(snapshot.value(metric))
        }
        latest = snapshot
    }

    /// The newest `count` samples for a metric, oldest first.
    public func recent(_ metric: MetricID, count: Int) -> [Double?] {
        history[metric]?.suffix(count) ?? []
    }
}
