// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "member-import-visibility-body-conflict",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "CustomProtocol"),

        // Peer module declaring its own `View` protocol with an `associatedtype Body`.
        // Used by V8 to attempt `Rendering::View` / `SwiftUI::View` disambiguation.
        .target(name: "Rendering"),

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

        // V7: @retroactive on the NSViewRepresentable conformance
        // Expected: REFUTED — @retroactive rejected; conforming type's module owns it
        .target(
            name: "V7_Retroactive"
        ),

        // V8: SE-0491 module selectors (`Rendering::View`, `SwiftUI::View`)
        // Expected: REFUTED — diagnostic says same-named associated types are merged,
        //           not shadowed; module selectors forbidden on dependent member types
        .target(
            name: "V8_ModuleSelectors",
            dependencies: ["Rendering"],
            swiftSettings: [.enableExperimentalFeature("ModuleSelector")]
        ),

        // V9: wrapper-property escape hatch — HTML.Document has no SwiftUI.View
        //     conformance; a `.swiftUIView` property returns a wrapper that does
        // Expected: CONFIRMED — compiles cleanly; ceremonial `.swiftUIView` suffix
        //           required at every #Preview call site
        .target(
            name: "V9_Wrapper_Escape_Hatch"
        ),

        // V10: Render namespace + `associatedtype Rendered` — the specific
        //      rename the blog post recommends (distinct from V6, which
        //      uses `Content`, a name SwiftUI already occupies).
        // Expected: CONFIRMED — `Rendered` simple identifier does not
        //           unify with SwiftUI.View.Body; NSViewRepresentable
        //           conformance compiles on the same HTML.Document shape
        //           that fails in V1–V5.
        .target(
            name: "V10_Rendered_Namespace"
        ),
    ]
)
