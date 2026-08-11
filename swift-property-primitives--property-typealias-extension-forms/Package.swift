// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "property-typealias-extension-forms",
    platforms: [
        .macOS(.v26)
    ],
    dependencies: [
        .package(path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "Test",
            dependencies: [
                .product(name: "Property Primitives", package: "swift-property-primitives")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
