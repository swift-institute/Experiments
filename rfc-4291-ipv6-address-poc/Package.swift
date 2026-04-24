// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "rfc-4291-ipv6-address-poc",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "rfc-4291-ipv6-address-poc"
        )
    ]
)
