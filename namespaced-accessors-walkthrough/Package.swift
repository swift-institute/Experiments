// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "namespaced-accessors-walkthrough",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "V1_BespokeProxy",
            swiftSettings: sharedSettings
        ),
        .executableTarget(
            name: "V2_FiveProxies",
            swiftSettings: sharedSettings
        ),
        .executableTarget(
            name: "V3_Wrapper",
            swiftSettings: sharedSettings
        ),
        .executableTarget(
            name: "V4_NoncopyableFails",
            swiftSettings: sharedSettings
        ),
        .executableTarget(
            name: "V5_View",
            swiftSettings: sharedSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)

var sharedSettings: [SwiftSetting] {
    [
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .unsafeFlags(["-parse-as-library"]),
    ]
}
