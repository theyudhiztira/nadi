import Foundation

public struct AppRelease: Decodable, Sendable, Equatable {
    public struct Asset: Decodable, Sendable, Equatable {
        public let name: String
        public let browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    public let tagName: String
    public let draft: Bool
    public let prerelease: Bool
    public let htmlURL: URL
    public let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case draft
        case prerelease
        case htmlURL = "html_url"
        case assets
    }
}

public struct AvailableUpdate: Sendable, Equatable {
    public let version: String
    public let pageURL: URL
    public let downloadURL: URL

    public init(version: String, pageURL: URL, downloadURL: URL) {
        self.version = version
        self.pageURL = pageURL
        self.downloadURL = downloadURL
    }
}

public enum UpdateCheck {
    private struct Version {
        var components: [Int]
        var suffix: String?
    }

    public static func compare(_ a: String, _ b: String) -> ComparisonResult? {
        guard let left = parse(a), let right = parse(b) else { return nil }
        for index in 0..<max(left.components.count, right.components.count) {
            let lhs = index < left.components.count ? left.components[index] : 0
            let rhs = index < right.components.count ? right.components[index] : 0
            if lhs != rhs { return lhs < rhs ? .orderedAscending : .orderedDescending }
        }
        switch (left.suffix, right.suffix) {
        case (nil, nil):
            return .orderedSame
        case (nil, .some):
            return .orderedDescending
        case (.some, nil):
            return .orderedAscending
        case let (.some(lhs), .some(rhs)):
            return (lhs as NSString).compare(rhs, options: [.numeric, .caseInsensitive])
        }
    }

    public static func newest(in data: Data, current: String) -> AvailableUpdate? {
        guard let releases = try? JSONDecoder().decode([AppRelease].self, from: data) else { return nil }
        let updates = releases.compactMap { release -> AvailableUpdate? in
            let version = release.tagName.hasPrefix("v") ? String(release.tagName.dropFirst()) : release.tagName
            guard !release.draft, compare(version, current) == .orderedDescending else { return nil }
            let downloadURL = release.assets.first(where: { $0.name == "Nadi-\(version).zip" })?.browserDownloadURL ?? release.htmlURL
            return AvailableUpdate(version: version, pageURL: release.htmlURL, downloadURL: downloadURL)
        }
        return updates.max { compare($0.version, $1.version) == .orderedAscending }
    }

    private static func parse(_ text: String) -> Version? {
        let value = text.hasPrefix("v") ? String(text.dropFirst()) : text
        let parts = value.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        guard let componentText = parts.first else { return nil }
        let components = componentText.split(separator: ".", omittingEmptySubsequences: false)
        guard !components.isEmpty,
              components.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy { (48...57).contains($0) } })
        else { return nil }
        let numbers = components.compactMap { Int($0) }
        guard numbers.count == components.count else { return nil }
        let suffix = parts.count == 2 ? String(parts[1]) : nil
        guard suffix?.isEmpty != true else { return nil }
        return Version(components: numbers, suffix: suffix)
    }
}
