// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "github-url-spm-resolution",
    platforms: [.macOS(.v26)],
    dependencies: [
        // Variant 1 & 2: Basic resolution from coenttb org
        .package(url: "https://github.com/coenttb/test-algebra-primitives", from: "0.1.0"),
        .package(url: "https://github.com/coenttb/test-buffer-primitives", from: "0.1.0"),

        // Variant 4: Name collision — same Package.name as test-buffer-primitives
        .package(url: "https://github.com/coenttb/test-buffer-foundations", from: "0.1.0"),
    ],
    targets: [
        .executableTarget(
            name: "github-url-spm-resolution",
            dependencies: [
                .product(name: "TestAlgebraPrimitives", package: "test-algebra-primitives"),
                .product(name: "TestBufferPrimitives", package: "test-buffer-primitives"),
                .product(name: "TestBufferFoundations", package: "test-buffer-foundations"),
            ]
        )
    ]
)
