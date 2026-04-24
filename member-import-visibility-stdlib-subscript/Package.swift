// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "member-import-visibility-stdlib-subscript",
    platforms: [.macOS(.v26)],
    targets: [
        // ── Library targets (mirrors production module structure) ──────────

        // Analogous to Tagged_Primitives: defines Tagged<Tag, Wrapped>
        .target(
            name: "TypeDefs",
            swiftSettings: [
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        // Analogous to Ordinal_Primitives_Core: protocol + conformances
        .target(
            name: "Core",
            dependencies: ["TypeDefs"],
            swiftSettings: [
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        // Analogous to Ordinal_Primitives_Standard_Library_Integration
        .target(
            name: "Extensions",
            dependencies: ["Core"],
            swiftSettings: [
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        // Analogous to Ordinal_Primitives umbrella
        .target(
            name: "Umbrella",
            dependencies: ["TypeDefs", "Core", "Extensions"],
            swiftSettings: [
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),

        // ── Executable variants ───────────────────────────────────────────

        // V1: Direct import of ALL modules, with MIV
        .executableTarget(
            name: "variant-direct",
            dependencies: ["TypeDefs", "Core", "Extensions"],
            swiftSettings: [
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        // V2: Import ONLY umbrella, with MIV
        .executableTarget(
            name: "variant-umbrella",
            dependencies: ["Umbrella"],
            swiftSettings: [
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        // V3: Import umbrella, WITHOUT MIV (control group)
        .executableTarget(
            name: "variant-no-miv",
            dependencies: ["Umbrella"],
            swiftSettings: [
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        // V4: Concrete conformer only (not conditional), with MIV + umbrella
        .executableTarget(
            name: "variant-concrete-only",
            dependencies: ["Umbrella"],
            swiftSettings: [
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        // V5: Non-generic subscript (no protocol constraint)
        .target(
            name: "SimpleExtension",
            swiftSettings: [
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .executableTarget(
            name: "variant-simple",
            dependencies: ["SimpleExtension"],
            swiftSettings: [
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        // V6: No features at all (raw baseline)
        .executableTarget(
            name: "variant-raw-baseline",
            dependencies: ["Extensions"],
            swiftSettings: []
        ),
        // V7: Same-module test (subscript + usage in one module)
        .executableTarget(
            name: "variant-same-module",
            swiftSettings: [
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        // V8: Absolute minimal reproduction — no features, no dependencies
        .executableTarget(
            name: "variant-minimal",
            swiftSettings: []
        ),
        // V9: Same as V8 but with MIV only
        .executableTarget(
            name: "variant-minimal-miv",
            swiftSettings: [
                .enableUpcomingFeature("MemberImportVisibility"),
            ]
        ),
        // V10: Same as V8 but with InternalImportsByDefault only
        .executableTarget(
            name: "variant-minimal-iibd",
            swiftSettings: [
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        // V11: Same as V8 but with BOTH features
        .executableTarget(
            name: "variant-minimal-both",
            swiftSettings: [
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
