// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "section-discovery-verification",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "section-discovery-verification",
            swiftSettings: [
                .enableUpcomingFeature("InternalImportsByDefault"),
                // NOTE: SymbolLinkageMarkers was removed in Swift 6.3.
                // Replaced by @section/@used (SE-0492) which are now stable language features.
                // @_section/@_used (underscored) failed in 6.2 with:
                // "global variable must be a compile-time constant to use @_section attribute"
                // In 6.3, @section/@used + #objectFormat are the official API.
            ]
        )
    ]
)
