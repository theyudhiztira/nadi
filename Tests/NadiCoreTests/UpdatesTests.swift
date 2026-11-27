import Foundation
import Testing
@testable import NadiCore

struct UpdatesTests {
    @Test func comparesVersions() {
        #expect(UpdateCheck.compare("0.0.1", "0.0.2") == .orderedAscending)
        #expect(UpdateCheck.compare("0.1.0", "0.0.9") == .orderedDescending)
        #expect(UpdateCheck.compare("v0.1.0", "0.1") == .orderedSame)
        #expect(UpdateCheck.compare("1.0", "1.0.1") == .orderedAscending)
        #expect(UpdateCheck.compare("0.2.0-beta.1", "0.2.0") == .orderedAscending)
        #expect(UpdateCheck.compare("garbage", "0.2.0") == nil)
    }

    @Test func picksNewestPublishedReleaseAndZip() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            [
                "tag_name": "v0.0.1",
                "draft": false,
                "prerelease": true,
                "html_url": "https://github.com/theyudhiztira/nadi/releases/tag/v0.0.1",
                "assets": [
                    ["name": "Nadi-0.0.1.zip", "browser_download_url": "https://github.com/theyudhiztira/nadi/releases/download/v0.0.1/Nadi-0.0.1.zip"],
                    ["name": "Nadi-0.0.1.zip.sha256", "browser_download_url": "https://github.com/theyudhiztira/nadi/releases/download/v0.0.1/Nadi-0.0.1.zip.sha256"],
                ],
            ],
            [
                "tag_name": "v0.0.3",
                "draft": false,
                "prerelease": true,
                "html_url": "https://github.com/theyudhiztira/nadi/releases/tag/v0.0.3",
                "assets": [
                    ["name": "Nadi-0.0.3.zip", "browser_download_url": "https://github.com/theyudhiztira/nadi/releases/download/v0.0.3/Nadi-0.0.3.zip"],
                ],
            ],
            [
                "tag_name": "v0.0.4",
                "draft": true,
                "prerelease": true,
                "html_url": "https://github.com/theyudhiztira/nadi/releases/tag/v0.0.4",
                "assets": [],
            ],
        ])
        let update = UpdateCheck.newest(in: data, current: "0.0.1")
        #expect(update?.version == "0.0.3")
        #expect(update?.pageURL.absoluteString == "https://github.com/theyudhiztira/nadi/releases/tag/v0.0.3")
        #expect(update?.downloadURL.absoluteString == "https://github.com/theyudhiztira/nadi/releases/download/v0.0.3/Nadi-0.0.3.zip")
    }

    @Test func skipsCurrentOrNewerVersion() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            [
                "tag_name": "v0.0.3",
                "draft": false,
                "prerelease": true,
                "html_url": "https://github.com/theyudhiztira/nadi/releases/tag/v0.0.3",
                "assets": [],
            ],
        ])
        #expect(UpdateCheck.newest(in: data, current: "0.0.3") == nil)
        #expect(UpdateCheck.newest(in: data, current: "0.0.4") == nil)
    }

    @Test func fallsBackToReleasePage() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            [
                "tag_name": "v0.0.2",
                "draft": false,
                "prerelease": true,
                "html_url": "https://github.com/theyudhiztira/nadi/releases/tag/v0.0.2",
                "assets": [["name": "Nadi-0.0.2.zip.sha256", "browser_download_url": "https://github.com/theyudhiztira/nadi/releases/download/v0.0.2/Nadi-0.0.2.zip.sha256"]],
            ],
        ])
        let update = UpdateCheck.newest(in: data, current: "0.0.1")
        #expect(update?.downloadURL.absoluteString == "https://github.com/theyudhiztira/nadi/releases/tag/v0.0.2")
    }

    @Test func malformedJSONReturnsNil() {
        #expect(UpdateCheck.newest(in: Data("not json".utf8), current: "0.0.1") == nil)
    }
}
