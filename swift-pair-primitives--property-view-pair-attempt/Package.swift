// swift-tools-version: 6.3
import PackageDescription

let experimentSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .enableExperimentalFeature("Lifetimes"),
    .enableExperimentalFeature("SuppressedAssociatedTypes"),
    .enableUpcomingFeature("LifetimeDependence"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),
]

let pairProduct: Target.Dependency = .product(name: "Pair Primitives", package: "swift-pair-primitives")
let propertyProduct: Target.Dependency = .product(name: "Property Primitives", package: "swift-property-primitives")

let package = Package(
    name: "property-view-pair-attempt",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../.."),
        .package(url: "https://github.com/swift-primitives/swift-property-primitives.git", branch: "main"),
    ],
    targets: [
        .executableTarget(name: "variant-1-property-typed",
                          dependencies: [pairProduct, propertyProduct],
                          swiftSettings: experimentSettings),
        .executableTarget(name: "variant-2-pairlike-bridge",
                          dependencies: [pairProduct, propertyProduct],
                          swiftSettings: experimentSettings),
        .executableTarget(name: "variant-3-type-changing-method",
                          dependencies: [pairProduct, propertyProduct],
                          swiftSettings: experimentSettings),
        .executableTarget(name: "variant-4-property-consume",
                          dependencies: [pairProduct, propertyProduct],
                          swiftSettings: experimentSettings),
        .executableTarget(name: "variant-5-property-inout",
                          dependencies: [pairProduct, propertyProduct],
                          swiftSettings: experimentSettings),
    ]
)
