// swift-tools-version: 6.0
import Foundation
import PackageDescription

// Command Line Tools keep the Swift Testing macro plugin off the default search path; without it `@Test` fails to expand.
let cltTestingPlugins = "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing"
let testSwiftSettings: [SwiftSetting] = FileManager.default.fileExists(atPath: cltTestingPlugins)
    ? [.unsafeFlags(["-plugin-path", cltTestingPlugins])]
    : []

let package = Package(
    name: "Nadi",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Nadi", targets: ["NadiApp"]),
    ],
    targets: [
        .executableTarget(
            name: "NadiApp",
            dependencies: ["NadiCore", "NadiSensors"]
        ),
        .target(name: "NadiCore"),
        .target(
            name: "NadiSensors",
            dependencies: ["NadiCore", "CPrivate"]
        ),
        .target(name: "CPrivate"),
        .testTarget(
            name: "NadiCoreTests",
            dependencies: ["NadiCore"],
            swiftSettings: testSwiftSettings
        ),
    ]
)
