// swift-tools-version: 6.3.1
import PackageDescription

// Experiment: set-algebra-composition
//
// Backs the technical claim of the Set.Buildable.Protocol decoupling (2026-05-30):
// after deleting the bundled Set.Buildable.Protocol, the REAL ordered-set variants
// compose with the orthogonal set algebra purely by `import`-ing both packages —
// "builder-primitives × set-primitives, composed at the consumer". This is the
// cross-variant integration coverage that the ⊥ invariant forbids from living in
// either source package (set-ordered ⊥ set-algebra, library AND test).
//
// Deps url+mirror (the ecosystem convention) — resolves via the SPM mirror to the
// local checkouts now, via remotes once the URL-migration is pushed.

let package = Package(
    name: "set-algebra-composition",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-set-ordered-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-set-algebra-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-builder-primitives.git", branch: "main"),
    ],
    targets: [
        .testTarget(
            name: "Set Algebra Composition Tests",
            dependencies: [
                .product(name: "Set Ordered Primitives", package: "swift-set-ordered-primitives"),
                .product(name: "Set Algebra Primitives", package: "swift-set-algebra-primitives"),
                .product(name: "Builder Primitives", package: "swift-builder-primitives"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .enableExperimentalFeature("Lifetimes"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
