// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "parser-printer-codec",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "parser-printer-codec",
            dependencies: [
                .product(name: "RFC 8259", package: "swift-rfc-8259"),
            ]
        )
    ]
)
