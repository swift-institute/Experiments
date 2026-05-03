// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "se-0499-stdlib-noncopyable-protocol-conformance",
    platforms: [.macOS(.v26)],
    targets: [
        .target(
            name: "SE0499Spike"
        ),
        .target(
            name: "SE0499SpikeTypealias"
        ),
    ]
)
