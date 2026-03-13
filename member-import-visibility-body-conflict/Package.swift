// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "member-import-visibility-body-conflict",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "CustomProtocol"),

        // V1: public import SwiftUI in SAME FILE as stored `body` property
        // MemberImportVisibility ON
        // Expected: CONFLICT — compiler sees body and tries to satisfy SwiftUI.View.body
        .target(
            name: "V1_SameFile",
            dependencies: ["CustomProtocol"],
            swiftSettings: [.enableUpcomingFeature("MemberImportVisibility")]
        ),

        // V2: public import SwiftUI in DIFFERENT FILE, MemberImportVisibility ON
        // Expected: CONFLICT — MIV leaks SwiftUI.View to all files
        .target(
            name: "V2_MIV_Enabled",
            dependencies: ["CustomProtocol"],
            swiftSettings: [.enableUpcomingFeature("MemberImportVisibility")]
        ),

        // V3: public import SwiftUI in DIFFERENT FILE, MemberImportVisibility OFF
        // Expected: SUCCESS — this is the coenttb case
        .target(
            name: "V3_MIV_Disabled",
            dependencies: ["CustomProtocol"]
        ),

        // V4: internal import SwiftUI, MemberImportVisibility ON
        // Expected: FAIL — conformance visibility > import visibility
        .target(
            name: "V4_Internal_Import",
            dependencies: ["CustomProtocol"],
            swiftSettings: [.enableUpcomingFeature("MemberImportVisibility")]
        ),

        // V5: package import SwiftUI, MemberImportVisibility ON
        // Expected: UNKNOWN — test if package import avoids the leak
        .target(
            name: "V5_Package_Import",
            dependencies: ["CustomProtocol"],
            swiftSettings: [.enableUpcomingFeature("MemberImportVisibility")]
        ),

        // V6: Associated type named `Content` (not `Body`) — matches coenttb Renderable
        // Expected: SUCCESS — no name collision with SwiftUI.View.Body
        .target(
            name: "V6_Content_AssocType",
            swiftSettings: [.enableUpcomingFeature("MemberImportVisibility")]
        ),
    ]
)
