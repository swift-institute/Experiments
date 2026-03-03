// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "atexit-swiftsyntax-rewrite",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax", "602.0.0"..<"603.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "atexit-swiftsyntax-rewrite",
            dependencies: [
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
            ]
        )
    ]
)
