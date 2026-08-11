// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "rawlayout-automatic-sizing",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "rawlayout-automatic-sizing",
            swiftSettings: [
                .enableExperimentalFeature("RawLayout"),
            ]
        )
    ]
)
