// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "ipv6-address-alignment",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "ipv6-address-alignment",
            dependencies: [
                .product(name: "RFC 4291", package: "swift-rfc-4291")
            ]
        )
    ]
)
