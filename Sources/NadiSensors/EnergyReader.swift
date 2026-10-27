import CPrivate
import Foundation
import NadiCore

/// GPU watts from IOReport `Energy Model / GPU Energy`; CPU and system watts from SMC power keys.
/// On macOS 27 the IOReport CPU channels are frozen for unprivileged readers (docs/spikes.md).
public final class EnergyReader: EnergySensor, @unchecked Sendable {
    // Only touched from the Sampler actor.
    private let smc: SMC?
    private let subscription: IOReportSubscriptionRef?
    private let channels: CFMutableDictionary?
    private var previous: (sample: CFDictionary, date: Date)?

    public init() {
        smc = SMC()
        var subscribed: Unmanaged<CFMutableDictionary>?
        if let group = IOReportCopyChannelsInGroup("Energy Model" as CFString, nil, 0, 0, 0),
           let gpuOnly = Self.keepingOnly("GPU Energy", in: group),
           let subscription = IOReportCreateSubscription(nil, gpuOnly, &subscribed, 0, nil),
           let channels = subscribed?.takeRetainedValue() {
            self.subscription = subscription
            self.channels = channels
        } else {
            subscription = nil
            channels = nil
        }
    }

    /// Sampling all 162 Energy Model channels every tick is the costliest read Nadi makes; one is enough.
    private static func keepingOnly(_ channelName: String, in group: CFMutableDictionary) -> CFMutableDictionary? {
        guard let dict = (group as NSDictionary).mutableCopy() as? NSMutableDictionary,
              let channels = dict["IOReportChannels"] as? [CFDictionary]
        else { return nil }
        let kept = channels.filter { IOReportChannelGetChannelName($0) as String? == channelName }
        guard !kept.isEmpty else { return nil }
        dict["IOReportChannels"] = kept
        return dict as CFMutableDictionary
    }

    public func reading() -> EnergyReading? {
        let reading = EnergyReading(
            cpuWatts: smc?.readDouble("PHPC"),
            gpuWatts: gpuWatts(),
            systemWatts: smc?.readDouble("PSTR")
        )
        return reading == EnergyReading() ? nil : reading
    }

    private func gpuWatts() -> Double? {
        guard let subscription, let channels, let sample = IOReportCreateSamples(subscription, channels, nil) else { return nil }
        let now = Date()
        defer { previous = (sample, now) }
        guard let previous,
              let delta = IOReportCreateSamplesDelta(previous.sample, sample, nil) as? [String: Any],
              let items = delta["IOReportChannels"] as? [CFDictionary]
        else { return nil }
        let seconds = now.timeIntervalSince(previous.date)
        guard seconds > 0 else { return nil }
        for item in items where IOReportChannelGetChannelName(item) as String? == "GPU Energy" {
            let unit = (IOReportChannelGetUnitLabel(item) as String? ?? "").trimmingCharacters(in: .whitespaces)
            let value = Double(IOReportSimpleGetIntegerValue(item, 0))
            let joules: Double? = switch unit {
            case "mJ": value / 1e3
            case "uJ": value / 1e6
            case "nJ": value / 1e9
            default: nil
            }
            return joules.map { $0 / seconds }
        }
        return nil
    }
}
