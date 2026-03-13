// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "nsviewrepresentable-body-witness",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "CustomProtocol"),

        // V1: Minimal — custom protocol body + NSViewRepresentable, generic param NOT named Body
        // Expected: SUCCESS — no name collision on associated type
        .target(
            name: "V1_Minimal",
            dependencies: ["CustomProtocol"],
            swiftSettings: [.enableUpcomingFeature("MemberImportVisibility")]
        ),

        // V2: Both protocols use associatedtype Body — test name collision
        // Expected: UNKNOWN — does compiler disambiguate?
        .target(
            name: "V2_AssocType_Collision",
            dependencies: ["CustomProtocol"],
            swiftSettings: [.enableUpcomingFeature("MemberImportVisibility")]
        ),

        // V3: Generic parameter named Body (the actual HTML.Document case)
        // Expected: CONFLICT — Body satisfies CustomView.Body but not SwiftUI.View.Body
        .target(
            name: "V3_GenericParam_Body",
            dependencies: ["CustomProtocol"],
            swiftSettings: [.enableUpcomingFeature("MemberImportVisibility")]
        ),

        // V4: With result builder on custom protocol's body requirement
        // Expected: same as V3 but testing @resultBuilder interaction
        .target(
            name: "V4_ResultBuilder",
            dependencies: ["CustomProtocol"],
            swiftSettings: [.enableUpcomingFeature("MemberImportVisibility")]
        ),
    ]
)
