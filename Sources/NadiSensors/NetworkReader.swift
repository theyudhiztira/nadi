import Darwin
import Foundation
import NadiCore

/// Uses `NET_RT_IFLIST2` because its `if_data64` counters are 64-bit; `getifaddrs` wraps at 4 GB.
/// Listing every interface costs about 2 ms, so the reader lists once a minute and otherwise asks only for the
/// interfaces that have carried traffic.
public final class NetworkReader: NetworkSensor, @unchecked Sendable {
    // Only touched from the Sampler actor.
    private var active: [UInt16] = []
    private var listedAt: Date?

    public init() {}

    public func counters() -> ByteCounters? {
        if listedAt.map({ Date().timeIntervalSince($0) >= 60 }) ?? true {
            let previous = active
            guard let all = Self.read(interface: 0) else { return nil }
            active = all.filter { $0.received > 0 || $0.sent > 0 }.map(\.index)
            listedAt = Date()
            // A changed interface set changes the sum; returning nil makes the sampler start a fresh delta.
            if previous != active, !previous.isEmpty { return nil }
            return Self.sum(all.filter { active.contains($0.index) })
        }
        var stats: [(index: UInt16, received: UInt64, sent: UInt64)] = []
        for index in active {
            // An interface that went away invalidates the cached list.
            guard let entry = Self.read(interface: index)?.first else {
                listedAt = nil
                return nil
            }
            stats.append(entry)
        }
        return Self.sum(stats)
    }

    private static func sum(_ stats: [(index: UInt16, received: UInt64, sent: UInt64)]) -> ByteCounters {
        ByteCounters(inBytes: stats.reduce(0) { $0 &+ $1.received }, outBytes: stats.reduce(0) { $0 &+ $1.sent })
    }

    /// Interface 0 lists all interfaces except loopback; any other index lists just that one.
    private static func read(interface: UInt16) -> [(index: UInt16, received: UInt64, sent: UInt64)]? {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, Int32(interface)]
        var length = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &length, nil, 0) == 0, length > 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: length)
        guard sysctl(&mib, UInt32(mib.count), &buffer, &length, nil, 0) == 0 else { return nil }

        var result: [(index: UInt16, received: UInt64, sent: UInt64)] = []
        var name = [CChar](repeating: 0, count: Int(IF_NAMESIZE))
        buffer.withUnsafeBytes { raw in
            var offset = 0
            while offset + MemoryLayout<if_msghdr>.size <= length {
                let header = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr.self)
                guard header.ifm_msglen > 0 else { break }
                if header.ifm_type == RTM_IFINFO2, offset + MemoryLayout<if_msghdr2>.size <= length {
                    let info = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                    let isLoopback = if_indextoname(UInt32(info.ifm_index), &name) != nil
                        && String(decoding: name.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self).hasPrefix("lo")
                    if !isLoopback {
                        result.append((info.ifm_index, info.ifm_data.ifi_ibytes, info.ifm_data.ifi_obytes))
                    }
                }
                offset += Int(header.ifm_msglen)
            }
        }
        return result
    }
}
